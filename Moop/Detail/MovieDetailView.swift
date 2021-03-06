//
//  MovieDetailView.swift
//  Moop
//
//  Created by Chang Woo Son on 23/05/2019.
//  Copyright © 2019 kor45cw. All rights reserved.
//

import UIKit
import StoreKit
import SafariServices
import kor45cw_Extension

protocol DetailHeaderDelegate: class {
    func wrapper(type: TheaterType)
    func poster(_ image: UIImage)
    func privacy()
}

class MovieDetailView: UIViewController {
    static func instance(id: String) -> MovieDetailView {
        let vc: MovieDetailView = instance(storyboardName: Storyboard.detail)
        vc.presenter = MovieDetailPresenter(view: vc, moopId: id)
        return vc
    }
    
    var presenter: MovieDetailPresenterDelegate!
    
    @IBOutlet private weak var alarmButton: UIBarButtonItem!
    @IBOutlet private weak var tableView: UITableView! {
        didSet {
            tableView.register(MovieInfoPlotCell.self)
            tableView.register(TrailerHeaderCell.self)
            tableView.register(TrailerCell.self)
            tableView.register(TrailerFooterCell.self)
            tableView.register(NaverInfoCell.self)
            tableView.register(TheaterCell.self)
            tableView.register(PosterWithInfoCell.self)
            tableView.register(BoxOfficeCell.self)
            tableView.register(ImdbCell.self)
            tableView.register(NativeAdMasterCell.self)
        }
    }
    
    @IBOutlet private weak var bannerWrpperView: UIView!
    @IBOutlet private weak var bannerViewHeightConstraint: NSLayoutConstraint!
    private lazy var 광고모듈: AdManager = AdManager(배너광고타입: .상세,
                                                   viewController: self,
                                                   wrapperView: bannerWrpperView,
                                                   네이티브광고타입: .상세)
    
    override func viewDidLoad() {
        super.viewDidLoad()
        configureAd()
        presenter.viewDidLoad()
    }
    
    private func configureAd() {
        guard !UserData.isAdFree else {
            bannerWrpperView.removeFromSuperview()
            return
        }
        광고모듈.delegate = self
        광고모듈.배너보여줘()
        광고모듈.네이티브광고보여줘()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        loadBannerAd()
    }
    
    override func viewWillTransition(to size: CGSize,
                                     with coordinator: UIViewControllerTransitionCoordinator) {
        coordinator.animate(alongsideTransition: { _ in
            self.loadBannerAd()
        })
    }
    
    func loadBannerAd() {
        guard !UserData.isAdFree else { return }
        let viewWidth = view.frame.inset(by: view.safeAreaInsets).size.width
        bannerViewHeightConstraint.constant = 광고모듈.resize배너(width: viewWidth)
    }
    
    func isAllowedToOpenStoreReview() -> Bool {
        // 365일 내에 최대 3회까지 사용자에게만 표시된다는 사실을 알고있어야 합니다.
        // TODO: 1년 지난 후에는 체크 하는 로직 만들어야
        let launchCount = UserData.detailViewCount
        let isOpen = launchCount == 3 || launchCount == 10 || launchCount == 20
        if launchCount == 3 {
            UserData.firstReviewDate = Date()
        }
        UserData.detailViewCount = launchCount + 1
        return isOpen
    }
    
    @IBAction private func share(_ sender: UIBarButtonItem) {
        share(sender: sender)
    }
    
    @IBAction private func alarm(_ sender: UIBarButtonItem) {
        sender.tag = sender.tag == 0 ? 1 : 0
        sender.image = sender.tag == 1 ? UIImage(systemName: "bell.fill") : UIImage(systemName: "bell")
        alarm(isAdd: sender.tag == 1)
    }
    
    private func alarm(isAdd: Bool) {
        isAdd ? NotificationManager.shared.addNotification(item: presenter.movieInfo) :
            NotificationManager.shared.removeNotification(item: presenter.movieInfo)
        
        presenter.changeAlarm(isAlarm: isAdd)
    }
}

extension MovieDetailView: DetailHeaderDelegate {
    func wrapper(type: TheaterType) {
        guard let url = presenter.webURL(with: type) else { return }
        let safariViewController = SFSafariViewController(url: url)
        present(safariViewController, animated: true, completion: nil)
    }
    
    func share(sender: UIBarButtonItem? = nil) {
        let viewController = UIActivityViewController(activityItems: [presenter.movieInfo?.shareText ?? ""], applicationActivities: [])
        if UIDevice.current.userInterfaceIdiom == .pad {
            if sender != nil {
                viewController.popoverPresentationController?.barButtonItem = self.navigationItem.rightBarButtonItem
            } else {
                viewController.popoverPresentationController?.sourceView = self.view
                viewController.popoverPresentationController?.sourceRect = CGRect(x: 0, y: 0,
                                                                                  width: self.view.frame.size.width / 2,
                                                                                  height: self.view.frame.size.height / 4)
            }
        }
        present(viewController, animated: true, completion: nil)
    }
    
    func poster(_ image: UIImage) {
        let posterViewController = PosterViewController.instance(image: image)
        posterViewController.modalPresentationStyle = .fullScreen
        self.present(posterViewController, animated: true)
    }
    
    func privacy() {
        guard let url = URL(string: "https://policies.google.com/privacy") else { return }
        let safariViewController = SFSafariViewController(url: url)
        present(safariViewController, animated: true, completion: nil)
    }
}

extension MovieDetailView: MovieDetailViewDelegate {
    func loadFinished() {
        alarmButton.tag = presenter.isAlarm ? 1 : 0
        alarmButton.image = alarmButton.tag == 1 ? UIImage(systemName: "bell.fill") : UIImage(systemName: "bell")
        title = presenter.title
        if isAllowedToOpenStoreReview() {
            SKStoreReviewController.requestReview()
        }
        tableView.reloadData()
    }
    
    func loadFailed() {
        
    }
}

extension MovieDetailView: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return presenter.numberOfItemsInSection
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cellType = presenter[indexPath] else { return UITableViewCell() }
        
        switch cellType {
        case .header:
            let cell: PosterWithInfoCell = tableView.dequeueReusableCell(for: indexPath)
            cell.set(presenter.movieInfo)
            cell.delegate = self
            return cell
        case .boxOffice:
            let cell: BoxOfficeCell = tableView.dequeueReusableCell(for: indexPath)
            cell.set(presenter.movieInfo)
            return cell
        case .imdb:
            let cell: ImdbCell = tableView.dequeueReusableCell(for: indexPath)
            cell.set(presenter.movieInfo)
            return cell
        case .cgv:
            let cell: TheaterCell = tableView.dequeueReusableCell(for: indexPath)
            cell.set(presenter.movieInfo)
            cell.delegate = self
            return cell
        case .naver:
            let cell: NaverInfoCell = tableView.dequeueReusableCell(for: indexPath)
            cell.set(presenter.movieInfo?.naverInfo)
            cell.delegate = self
            return cell
        case .plot:
            let cell: MovieInfoPlotCell = tableView.dequeueReusableCell(for: indexPath)
            cell.configure(presenter.movieInfo?.plot)
            return cell
        case .trailerHeader:
            let cell: TrailerHeaderCell = tableView.dequeueReusableCell(for: indexPath)
            cell.set(presenter.title)
            cell.delegate = self
            return cell
        case .trailer(let trailerInfo):
            let cell: TrailerCell = tableView.dequeueReusableCell(for: indexPath)
            cell.set(trailerInfo)
            return cell
        case .trailerFooter:
            let cell: TrailerFooterCell = tableView.dequeueReusableCell(for: indexPath)
            return cell
        case .ad:
            let cell: NativeAdMasterCell = tableView.dequeueReusableCell(for: indexPath)
            cell.configure(광고모듈.네이티브광고, viewController: self)
            return cell
        }
    }
}

extension MovieDetailView: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard let cellType = presenter[indexPath] else { return }
        
        switch cellType {
        case .boxOffice, .naver:
            wrapper(type: .naver)
        case .trailer(let trailerInfo):
            guard let youtubeURL = URL(string:"youtube://\(trailerInfo.youtubeId)"),
                let httpURL = URL(string:"https://www.youtube.com/watch?v=\(trailerInfo.youtubeId)") else { return }
            if UIApplication.shared.canOpenURL(youtubeURL) {
                UIApplication.shared.open(youtubeURL, options: [:], completionHandler: nil)
            } else {
                UIApplication.shared.open(httpURL, options: [:], completionHandler: nil)
            }
        case .trailerFooter:
            let title = presenter.title.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed)
            guard let httpURL = URL(string: "https://www.youtube.com/results?search_query=\(title ?? "")"),
                let youtubeURL = URL(string: "youtube://www.youtube.com/results?search_query=\(title ?? "")") else { return }
            if UIApplication.shared.canOpenURL(youtubeURL) {
                UIApplication.shared.open(youtubeURL, options: [:], completionHandler: nil)
            } else {
                UIApplication.shared.open(httpURL, options: [:], completionHandler: nil)
            }
        default: break
        }
    }
}

extension MovieDetailView: AdManagerDelegate {
    func 배너광고Loaded() {
        loadBannerAd()
    }
    
    func 네이티브광고Loaded() {
        guard let index = presenter.adIndex else { return }
        tableView.beginUpdates()
        tableView.insertRows(at: [IndexPath(item: index, section: 0)], with: .automatic)
        tableView.endUpdates()
    }
}
