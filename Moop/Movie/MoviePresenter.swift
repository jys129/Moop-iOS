//
//  MoviePresenter.swift
//  Moop
//
//  Created by kor45cw on 2019/10/12.
//  Copyright © 2019 kor45cw. All rights reserved.
//

import UIKit
import RealmSwift
import Networking

enum MovieContextMenuType {
    case text(String)
    case theater(TheaterType, URL?)
}

class MoviePresenter: NSObject {
    internal weak var view: MovieViewDelegate!
    
    private var notificationToken: NotificationToken?
    
    private var currentMovieData = MovieModel()
    private var futureMovieData = MovieModel()
    
    private var state: MovieType = .current {
        didSet {
            guard oldValue != state else { return }
            view.change(state: state)
            changedType()
        }
    }
    
    enum MovieType: Int {
        case current = 0
        case future
        
        var title: String {
            switch self {
            case .current:
                return "현재 상영".localized
            case .future:
                return "개봉 예정".localized
            }
        }
    }
    
    init(view: MovieViewDelegate) {
        self.view = view
        super.init()
        setupNotification()
    }
    
    deinit {
        notificationToken?.invalidate()
    }
    
    private func setupNotification() {
        notificationToken = RealmManager.shared.fetchNotification { [weak self] changes in
            guard let self = self else { return }
            switch changes {
            case let .initial(results):
                self.currentMovieData.items = results
                    .filter("now == true").sorted(byKeyPath: "score", ascending: true).compactMap { $0 }
                self.futureMovieData.items = results.filter("now == false").sorted(byKeyPath: "getDay").compactMap { $0 }
                self.filterItemChanged()
            case let .update(results, _, _, _):
                self.currentMovieData.items = results.filter("now == true").sorted(byKeyPath: "score", ascending: true).compactMap { $0 }
                self.futureMovieData.items = results.filter("now == false").sorted(byKeyPath: "getDay").compactMap { $0 }
                self.filterItemChanged()
            case let .error(error):
                print("An error occurred: \(error)")
            }
        }
    }
    
    var isEmpty: Bool {
        switch state {
        case .current:
            return currentMovieData.items.isEmpty
        case .future:
            return futureMovieData.items.isEmpty
        }
    }
}

extension MoviePresenter: FilterChangeDelegate {
    func filterItemChanged() {
        switch state {
        case .current:
            currentMovieData.filtered()
            view.loadFinished(currentMovieData.filteredMovies)
            
        case .future:
            futureMovieData.filtered()
            view.loadFinished(futureMovieData.filteredMovies)
        }
    }
}

extension MoviePresenter: UISearchResultsUpdating, UISearchBarDelegate {
    // MARK: - UISearchResultsUpdating Delegate
    func updateSearchResults(for searchController: UISearchController) {
        switch state {
        case .current:
            currentMovieData.search(query: searchController.searchBar.text ?? "")
            view.loadFinished(searchController.isActive ? currentMovieData.searchedMovies : currentMovieData.filteredMovies)
        case .future:
            futureMovieData.search(query: searchController.searchBar.text ?? "")
            view.loadFinished(searchController.isActive ? futureMovieData.searchedMovies : futureMovieData.filteredMovies)
        }
    }
}

extension MoviePresenter: MoviePresenterDelegate {
    func viewDidLoad() {
        checkCurrentUpdateTime()
    }
    
    func fetchContextMenus(item: Movie?) -> [UIAction] {
        guard let item = item else { return [] }
        var menus: [UIAction] = []
        
        item.contextMenus.forEach {
            switch $0 {
            case let .text(shareText):
                menus.append(UIAction(title: "Share", image: UIImage(named: "share"), identifier: nil) { [weak view] _ in
                    view?.share(text: shareText)
                })
            case let .theater(type, url):
                menus.append(UIAction(title: type.title, image: nil, identifier: nil) { [weak view] _ in
                    view?.rating(type: type, url: url)
                })
            }
        }
        return menus
    }
    
    private func changedType() {
        switch state {
        case .current:
            if currentMovieData.items.isEmpty {
                checkCurrentUpdateTime()
            } else {
                filterItemChanged()
            }
        case .future:
            if futureMovieData.items.isEmpty {
                checkFutureUpdateTime()
            } else {
                filterItemChanged()
            }
        }
    }
    
    func fetchDatas() {
        switch state {
        case .current:
            checkCurrentUpdateTime()
            
        case .future:
            checkFutureUpdateTime()
        }
    }
    
    private func checkCurrentUpdateTime() {
//        requestCurrentUpdateTime { [weak self] isUpdatedRequire in
//            if isUpdatedRequire {
                fetchCurrentDatas()
//            } else {
//                self?.filterItemChanged()
//            }
//        }
    }
    
    private func requestCurrentUpdateTime(completionHandler: @escaping (Bool) -> Void) {
        API.shared.requestCurrentUpdateTime { result in
            switch result {
            case .success(let updatedTime):
                let result = MovieTimeData.currentUpdatedTime.isEmpty || (MovieTimeData.currentUpdatedTime != updatedTime)
                completionHandler(result)
                MovieTimeData.currentUpdatedTime = updatedTime
            case .failure(let error):
                print("Error requestCurrentUpdateTime", error.localizedDescription)
            }
        }
    }
    
    private func fetchCurrentDatas() {
        API.shared.requestCurrent { [weak self] (result: Result<[MovieResponse], Error>) in
            guard let self = self else { return }
            switch result {
            case .success(let result):
                if !result.isEmpty {
                    self.saveData(items: result.map { Movie(response: $0) }, type: .current)
                } else {
                    self.filterItemChanged()
                }
            case .failure(let error):
                print("Error fetchCurrentDatas", error.localizedDescription)
            }
        }
    }
    
    private func checkFutureUpdateTime() {
//        requestFutureUpdateTime { [weak self] isUpdatedRequire in
//            if isUpdatedRequire {
                fetchFutureDatas()
//            } else {
//                self?.filterItemChanged()
//            }
//        }
    }
    
    private func requestFutureUpdateTime(completionHandler: @escaping (Bool) -> Void) {
        API.shared.requestFutureUpdateTime { result in
            switch result {
            case .success(let updatedTime):
                let result = MovieTimeData.futureUpdatedTime.isEmpty || (MovieTimeData.futureUpdatedTime != updatedTime)
                completionHandler(result)
                MovieTimeData.futureUpdatedTime = updatedTime
            case .failure(let error):
                print("Error requestCurrentUpdateTime", error.localizedDescription)
            }
        }
    }
    
    private func fetchFutureDatas() {
        API.shared.requestFuture { [weak self] (result: Result<[MovieResponse], Error>) in
            guard let self = self else { return }
            switch result {
            case .success(let result):
                if !result.isEmpty {
                    self.saveData(items: result.map { Movie(response: $0) }, type: .future)
                } else {
                    self.filterItemChanged()
                }
            case .failure(let error):
                print("Error fetchCurrentDatas", error.localizedDescription)
            }
        }
    }
    
    func updateState(_ index: Int) {
        state = MovieType(rawValue: index) ?? .current
    }
    
    private func saveData(items: [Movie], type: MovieType) {
        var willDeleteItem: [Movie] = []
        switch type {
        case .current:
            willDeleteItem = currentMovieData.items.filter { !items.map { $0.id }.contains($0.id) }
            let targetItem = currentMovieData.items.filter { items.map { $0.id }.contains($0.id) }
            view.loadFinished(targetItem)
        case .future:
            willDeleteItem = futureMovieData.items.filter { !items.map { $0.id }.contains($0.id) }
            let targetItem = futureMovieData.items.filter { items.map { $0.id }.contains($0.id) }
            view.loadFinished(targetItem)
        }
        
        let deleteIds = willDeleteItem.map { $0.id }
        SpotlightManager.shared.removeIndexes(with: deleteIds)
        
        RealmManager.shared.deleteData(items: willDeleteItem)
        RealmManager.shared.beginWrite()
        items.forEach {
            if let movie: Movie = RealmManager.shared.fetchData(predicate: NSPredicate(format: "id = %@", $0.id)) {
                movie.set(movie: $0)
                return
            } else {
                RealmManager.shared.saveData(item: $0)
            }
        }
        RealmManager.shared.commitWrite()
    }
}
