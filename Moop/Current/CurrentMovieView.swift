//
//  CurrentMovieView.swift
//  Moop
//
//  Created by Chang Woo Son on 2019/06/23.
//  Copyright © 2019 kor45cw. All rights reserved.
//

import UIKit
import SafariServices

class CurrentMovieView: UIViewController {
    static func instance() -> CurrentMovieView {
        let vc: CurrentMovieView = instance(storyboardName: .main)
        vc.presenter = CurrentMoviePresenter(view: vc)
        return vc
    }
    
    var presenter: CurrentMoviePresenterDelegate!
    
    private let searchController = UISearchController(searchResultsController: nil)
    private let refreshControl = UIRefreshControl()
    @IBOutlet private weak var collectionView: UICollectionView! {
        didSet {
            collectionView.delegate = self
            collectionView.dataSource = self
//            refreshControl.addTarget(self, action: #selector(requestData), for: .valueChanged)
            collectionView.refreshControl = refreshControl
            collectionView.register(MovieCell.self)
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        presenter.fetchDatas()
    }
    
    var canScrollToTop: Bool = false
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        canScrollToTop = true
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        canScrollToTop = false
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        guard let identifier = segue.identifier else { return }
        
        switch identifier {
        case "toDetails":
            guard let destination = segue.destination as? MovieDetailViewController,
                let indexPath = sender as? IndexPath else { return }
            destination.item = presenter[indexPath]
        case "toFilter":
            guard let destinationNavi = segue.destination as? UINavigationController,
                let destination = destinationNavi.viewControllers.first as? FilterViewController else { return }
            destination.delegate = self
        default:
            break
        }
    }
}

extension CurrentMovieView: FilterChangeDelegate {
    func theaterChanged() {
        if let theaters: [TheaterType] = UserDefaults.standard.object([TheaterType].self, forKey: .theater) {
//            self.filteredMovies = datas.filter({ $0.contain(types: theaters) })
        } else {
//            self.filteredMovies = datas
        }
    }
}

extension CurrentMovieView: CurrentMovieViewDelegate {
    func loadFinished() {
        self.collectionView.reloadData()
        self.refreshControl.endRefreshing()
    }
    
    func loadFailed() {
        self.refreshControl.endRefreshing()
        // TODO: Fail Toast
    }
}

extension CurrentMovieView: ScrollToTopDelegate {
    func scrollToTop() {
        if collectionView != nil && !presenter.isEmpty {
            DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(100)) {
                self.collectionView.scrollToItem(at: IndexPath(item: 0, section: 0), at: .top, animated: true)
            }
        }
    }
}

extension CurrentMovieView: UICollectionViewDataSource {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return presenter.numberOfItemsInSection
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "MovieCell", for: indexPath) as? MovieCell else { return UICollectionViewCell() }
        cell.set(presenter[indexPath])
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        performSegue(withIdentifier: "toDetails", sender: indexPath)
    }

}

extension CurrentMovieView: UICollectionViewDelegateFlowLayout {
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        let cellWidth = (collectionView.bounds.width - 36) / 3
        return CGSize(width: cellWidth, height: cellWidth / 600.0 * 855)
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumLineSpacingForSectionAt section: Int) -> CGFloat {
        return 8
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumInteritemSpacingForSectionAt section: Int) -> CGFloat {
        return 0
    }
}

extension CurrentMovieView: UIViewControllerPreviewingDelegate {
    func previewingContext(_ previewingContext: UIViewControllerPreviewing, viewControllerForLocation location: CGPoint) -> UIViewController? {
        guard let indexPath = collectionView.indexPathForItem(at: location),
            let cell = collectionView.cellForItem(at: indexPath) else { return nil }
        
        previewingContext.sourceRect = cell.frame
        guard let destination = storyboard?.instantiateViewController(withIdentifier: "detail") as? MovieDetailViewController else { return nil }
//        destination.item = isFiltering() ? searchedMovies[indexPath.item] : filteredMovies[indexPath.item]
        destination.delegate = self
        return destination
    }
    
    func previewingContext(_ previewingContext: UIViewControllerPreviewing, commit viewControllerToCommit: UIViewController) {
        show(viewControllerToCommit, sender: self)
    }
}

extension CurrentMovieView: MovieDetailPickAndPopDelegate {
    func share(text: String) {
        let viewController = UIActivityViewController(activityItems: [text], applicationActivities: [])
        present(viewController, animated: true, completion: nil)
    }
    
    func rating(type: TheaterType, id: String) {
        let webURL: URL?
        switch type {
        case .cgv:
            webURL = URL(string: "http://m.cgv.co.kr/WebApp/MovieV4/movieDetail.aspx?MovieIdx=\(id)")
        case .lotte:
            webURL = URL(string: "http://www.lottecinema.co.kr/LCMW/Contents/Movie/Movie-Detail-View.aspx?movie=\(id)")
        case .megabox:
            webURL = URL(string: "http://m.megabox.co.kr/?menuId=movie-detail&movieCode=\(id)")
        }
        
        guard let url = webURL else { return }
        let safariViewController = SFSafariViewController(url: url)
        present(safariViewController, animated: true, completion: nil)
    }
}

