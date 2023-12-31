//
//  LeagueViewController.swift
//  Balizinha
//
//  Created by Bobby Ren on 6/24/18.
//  Copyright © 2018 Bobby Ren. All rights reserved.
//

import UIKit
import Balizinha
import FBSDKShareKit
import FirebaseDatabase
import Firebase
import RACameraHelper

class LeagueViewController: UIViewController {
    fileprivate enum Row: CaseIterable {
        case title
        case join
        case tags
        case info
        case players
        case share
    }
    fileprivate enum Section: CaseIterable {
        case info
        case feed
    }
    
    fileprivate var rows: [Row] = Row.allCases
    fileprivate var sections: [Section] = Section.allCases
    
    @IBOutlet weak var tableView: UITableView!
    var tagView: ResizableTagView?
    
    var league: League?
    var players: [Player] = []
    var roster: [String: Membership] = [:]
    
    weak var joinLeagueCell: LeagueButtonCell?
    weak var shareLeagueCell: LeagueButtonCell?
    
    fileprivate let shareService = ShareService() // must be retained by the class
    fileprivate let activityOverlay: ActivityIndicatorOverlay = ActivityIndicatorOverlay()

    // feed
    var feedItems: [FeedItem] = []
    var feedItemPhoto: UIImage?
    fileprivate var beginningReached: Bool = false
    
    // camera
    let cameraHelper = CameraHelper()

    @IBOutlet weak var feedInputView: UIView!
    @IBOutlet weak var buttonSend: UIButton!
    @IBOutlet weak var buttonImage: UIButton!
    @IBOutlet weak var inputMessage: UITextField!
    @IBOutlet weak var constraintBottomOffset: NSLayoutConstraint!
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 80
        
        navigationItem.title = league?.name
        
        if league?.info.isEmpty == true, let index = rows.firstIndex(of: .info){
            rows.remove(at: index)
        }
        if let league = league {
            let viewModel = ShareLeagueButtonViewModel(league: league)
            if !viewModel.buttonEnabled, let index = rows.firstIndex(of: .share){
                rows.remove(at: index)
            }
        }

        activityOverlay.setup(frame: view.frame)
        view.addSubview(activityOverlay)
        loadRoster()
        listenFor(.PlayerLeaguesChanged, action: #selector(loadPlayerLeagues), object: nil)
        self.listenFor(NotificationType.DisplayFeaturedEvent, action: #selector(handleEventDeepLink(_:)), object: nil)

        navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(close))
        
        cameraHelper.delegate = self
        setupFeedInput()
        loadFeedItems()
        
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillShow(_:)), name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillHide(_:)), name: UIResponder.keyboardWillHideNotification, object: nil)
    }
    
    @objc fileprivate func close() {
        navigationController?.dismiss(animated: true, completion: nil)
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        activityOverlay.setup(frame: view.frame)
    }

    func loadRoster() {
        guard !AIRPLANE_MODE else {
            roster = ["1": Membership(id: "1", status: "organizer")]
            observePlayers()
            return
        }
        activityOverlay.show()
        roster.removeAll()

        guard let league = league else { return }
        LeagueService.shared.memberships(for: league) { [weak self] (results) in
            self?.roster.removeAll()
            for membership in results ?? [] {
                self?.roster[membership.playerId] = membership
            }
            self?.observePlayers()
        }
    }
    
    @objc func loadPlayerLeagues() {
        // on join or leave, update the join button and also update player roster
        guard let player = PlayerService.shared.current.value else { return }
        // TODO: join/shareLeagueCell should be able to use roster and not require loading player's leagues
        LeagueService.shared.leagueMemberships(for: player) { [weak self] _ in
            DispatchQueue.main.async {
                self?.joinLeagueCell?.reset()
                self?.shareLeagueCell?.reset()
            }
        }
//        BOBBY TODO: roster is not showing correctly after user joins league
//        BOBBY TODO: leaguesViewController needs to listen and update too
        loadRoster()
    }
    
    func observePlayers() {
        guard !AIRPLANE_MODE else {
            players = [MockService.mockPlayerOrganizer()]
            tableView.reloadData()
            return
        }
        DispatchQueue.main.async {
            self.activityOverlay.show()
        }
        players.removeAll()
        let dispatchGroup = DispatchGroup()
        for (playerId, membership) in roster {
            guard membership.isActive else { continue }
            dispatchGroup.enter()
            print("Loading player id \(playerId)")
            PlayerService.shared.withId(id: playerId, completion: {[weak self] (player) in
                if let player = player as? Player {
                    print("Finished player id \(playerId)")
                    self?.players.append(player)
                }
                dispatchGroup.leave()
            })
        }
        dispatchGroup.notify(queue: DispatchQueue.main) { [weak self] in
            if let index = self?.rows.firstIndex(of: .players) {
                self?.tableView.reloadRows(at: [IndexPath(row: index, section: 0)], with: .automatic)
                self?.activityOverlay.hide()
            }
        }
    }
    
    func goToAddPlayers() {
        performSegue(withIdentifier: "toLeaguePlayers", sender: nil)
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "toLeaguePlayers", let controller = segue.destination as? LeaguePlayersListViewController {
            controller.league = league
            controller.delegate = self
            controller.roster = roster
            
            let isOwner = league?.ownerId == PlayerService.shared.current.value?.id
            controller.isEditOrganizerMode = isOwner || AIRPLANE_MODE
        }
    }
    
    @objc func keyboardWillShow(_ notification: Notification) {
        let userInfo:NSDictionary = notification.userInfo! as NSDictionary
        let keyboardFrame:NSValue = userInfo.value(forKey: UIResponder.keyboardFrameEndUserInfoKey) as! NSValue
        let keyboardRectangle = keyboardFrame.cgRectValue
        let keyboardHeight = keyboardRectangle.height
        constraintBottomOffset.constant = keyboardHeight
        tableView.superview?.setNeedsUpdateConstraints()
        tableView.superview?.layoutIfNeeded()
    }
    
    @objc func keyboardWillHide(_ notification: Notification) {
        constraintBottomOffset.constant = 0
    }
    
    fileprivate let sortFunc: ((FeedItem, FeedItem) -> Bool) = { item0, item1 in
        guard let date0 = item0.createdAt else { return false }
        guard let date1 = item1.createdAt else { return true }
        return date0 > date1
    }
}

// mark: - feedItems
extension LeagueViewController {
    func loadFeedItems() {
        loadCached()
        loadMore()
    }

    func load(completion:(()->Void)? = nil) {
        guard let league = league else { return }
        var lastKey: String? = nil
        // stored order is in descending key/timestamp
        if let feedItem = self.feedItems.last {
            lastKey = feedItem.id
        }
        FeedService.shared.loadFeedItems(for: league, lastKey: lastKey) { [weak self] feedItemIds in
            let group = DispatchGroup()
            
            var newFeedItems = [FeedItem]()
            var processingCount = 0
            for id in feedItemIds {
                if id == lastKey {
                    continue
                }
                processingCount += 1
                group.enter()
                FeedService.shared.withId(id: id) { (feedItem) in
                    if let feedItem = feedItem as? FeedItem {
                        newFeedItems.append(feedItem)
                    }
                    group.leave()
                }
            }
            guard processingCount > 0 else {
                self?.beginningReached = true
                completion?()
                return
            }

            group.notify(queue: DispatchQueue.main) { [weak self] in
                // sort in descending order
                guard let self = self else { return }
                newFeedItems = newFeedItems.sorted(by: self.sortFunc)
                if lastKey == nil {
                    self.feedItems = newFeedItems
                } else {
                    self.feedItems.append(contentsOf: newFeedItems)
                }
                completion?()
            }
        }
    }
    
    private func loadCached() {
        guard let league = league else { return }
        let items = FeedService.shared.feedItemsForLeague(league.id).sorted(by: self.sortFunc)
        self.feedItems = items
    }
    
    private func loadMore() {
        activityOverlay.show()
        load() { [weak self] in
            self?.tableView.reloadData()
            self?.activityOverlay.hide()
        }
    }
}

extension LeagueViewController: UITableViewDataSource {
    func numberOfSections(in tableView: UITableView) -> Int {
        return sections.count
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        guard section < sections.count else { return 0 }
        switch sections[section] {
        case .info:
            return rows.count
        case .feed:
            return feedItems.count + 1
        }
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if indexPath.section == sections.firstIndex(of: .info) {
            switch rows[indexPath.row] {
            case .title:
                let cell = tableView.dequeueReusableCell(withIdentifier: "LeagueTitleCell", for: indexPath) as! LeagueTitleCell
                cell.selectionStyle = .none
                cell.configure(league: league)
                return cell
            case .join:
                let cell = tableView.dequeueReusableCell(withIdentifier: "JoinLeagueCell", for: indexPath) as! LeagueButtonCell
                guard let league = league else { return cell }
                cell.selectionStyle = .none
                cell.delegate = self
                let viewModel = JoinLeagueButtonViewModel(league: league)
                cell.configure(league: league, viewModel: viewModel)
                joinLeagueCell = cell
                return cell
            case .share:
                let cell = tableView.dequeueReusableCell(withIdentifier: "ShareLeagueCell", for: indexPath) as! LeagueButtonCell
                guard let league = league else { return cell }
                cell.selectionStyle = .none
                cell.delegate = self
                let viewModel = ShareLeagueButtonViewModel(league: league)
                cell.configure(league: league, viewModel: viewModel)
                shareLeagueCell = cell
                return cell
            case .tags:
                let cell = tableView.dequeueReusableCell(withIdentifier: "LeagueTagsCell", for: indexPath) as! LeagueTagsCell
                cell.configure(league: league)
                return cell
            case .info:
                let cell = tableView.dequeueReusableCell(withIdentifier: "LeagueInfoCell", for: indexPath) as! LeagueInfoCell
                cell.selectionStyle = .none
                cell.configure(league: league)
                return cell
            case .players:
                let cell = tableView.dequeueReusableCell(withIdentifier: "LeaguePlayersCell", for: indexPath) as! LeaguePlayersCell
                cell.delegate = self
                cell.handleAddPlayers = { [weak self] in
                    self?.goToAddPlayers()
                }
                cell.roster = roster.compactMap {$0.value}
                cell.configure(players: players)
                return cell
            }
        } else if indexPath.section == sections.firstIndex(of: .feed) {
            return feedRow(for: indexPath)
        } else {
            return UITableViewCell()
        }
    }
    
    fileprivate func feedIndex(for indexPath: IndexPath) -> Int? {
        let row = indexPath.row
        let index = row //feedItems.count - row - 1
        guard index < feedItems.count, index >= 0 else { return nil }
        return index
    }
    
    fileprivate func feedRow(for indexPath: IndexPath) -> UITableViewCell {
        guard let index = feedIndex(for: indexPath) else {
            let cell = tableView.dequeueReusableCell(withIdentifier: "LoadMoreCell", for: indexPath)
            if beginningReached {
                cell.textLabel?.text = "You have reached the beginning"
            } else {
                cell.textLabel?.text = "Click to load more"
            }
            return cell
        }

        let feedItem = feedItems[index]
        let identifier: String
        if feedItem.hasPhoto {
            identifier = "FeedItemPhotoCell"
        } else if feedItem.actionId != nil {
            identifier = "FeedItemActionCell"
        } else {
            identifier = "FeedItemCell"
        }
        guard let cell = tableView.dequeueReusableCell(withIdentifier: identifier, for: indexPath) as? FeedItemCell else { return UITableViewCell() }
        cell.configure(with: feedItem)
        return cell
    }
    
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        guard section == sections.firstIndex(of: .feed) else { return nil }
        return feedInputView
    }
    
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        guard section == sections.firstIndex(of: .feed) else { return 0 }
        return 50
    }
    
    func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        guard let index = feedIndex(for: indexPath) else { return false }
        let item = feedItems[index]
        return item.userCreatedFeedItem && (item.type == .chat || item.type == .photo)
    }
}

extension LeagueViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        if indexPath.section == sections.firstIndex(of: .info), let index = rows.firstIndex(of: .tags), index == indexPath.row {
            inputTag()
        }
        
        if indexPath.section == sections.firstIndex(of: .feed) {
            if indexPath.row == feedItems.count {
                loadMore()
            } else if indexPath.row < feedItems.count, let index = feedIndex(for: indexPath) {
                let feedItem = feedItems[index]
                LoggingService.shared.log(event: .FeedItemClicked, info: ["type": feedItem.type.rawValue, "id": feedItem.id])
                if let actionId = feedItem.actionId {
                    ActionService().withId(id: actionId) { [weak self] (action) in
                        if let action = action, action.type == ActionType.chat {
                            let viewModel = ActionViewModel(action: action)
                            self?.simpleAlert(viewModel.displayDate, message: viewModel.displayString)
                        } else {
                            if let eventId = action?.eventId, let url = URL(string: "panna://events/\(eventId)") {
                                // use internal deeplink for easy navigation to event
                                DeepLinkService.shared.handle(url: url)
                            }
                        }
                    }
                } else {
                    if feedItem.type == FeedItemType.chat, let userId = feedItem.userId {
                        LoggingService.shared.log(event: .FeedItemChatViewed, info: ["id": feedItem.id])
                        PlayerService.shared.withId(id: userId, completion: { [weak self] (player) in
                            let displayMessage = feedItem.message ?? feedItem.defaultMessage
                            DispatchQueue.main.async {
                                if let player = player as? Player, let name = player.name {
                                    let title = "\(name) said:"
                                    self?.simpleAlert(title, message: displayMessage)
                                } else {
                                    self?.simpleAlert("Chat message:", message: displayMessage)
                                }
                            }
                        })
                    } else if feedItem.type == FeedItemType.photo {
                        // TODO
                    }
                }
            }
        }
    }

    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        guard let index = feedIndex(for: indexPath) else { return }
        let item = feedItems[index]

        if editingStyle == .delete {
            FeedService.delete(feedItem: item)
        }

    }
}

extension LeagueViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
}

extension LeagueViewController: PlayersScrollViewDelegate {
    func didSelectPlayer(player: Player) {
        guard let playerController = UIStoryboard(name: "Account", bundle: nil).instantiateViewController(withIdentifier: "PlayerViewController") as? PlayerViewController else { return }
        
        playerController.player = player
        self.navigationController?.pushViewController(playerController, animated: true)
    }
}

extension LeagueViewController: LeagueListDelegate {
    func didUpdateRoster() {
        loadRoster()
    }
}

extension LeagueViewController {
    func inputTag() {
        let alert = UIAlertController(title: "Add a tag", message: nil, preferredStyle: .alert)
        alert.addTextField { (textField : UITextField!) -> Void in
            textField.placeholder = "i.e. awesome"
        }
        alert.addAction(UIAlertAction(title: "OK", style: .default, handler: { [weak self] (action) in
            if let textField = alert.textFields?[0], let tag = textField.text {
                var tags = self?.league?.tags ?? []
                guard !tag.isEmpty, !tags.contains(tag) else { return }
                tags.append(tag)
                self?.league?.tags = tags
                self?.tableView.reloadData()
            }
        }))
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        self.present(alert, animated: true)
    }
}

extension LeagueViewController: LeagueButtonCellDelegate {
    func clickedLeagueButton(_ cell: LeagueButtonCell, league: League) {
        if cell == joinLeagueCell {
            joinLeague()
        } else if cell == shareLeagueCell {
            promptForShare()
        }
    }
    
    fileprivate func joinLeague() {
        guard let league = league else { return }
        guard PlayerService.shared.current.value != nil else {
            promptForSignup()
            return
        }
        if LeagueService.shared.playerIsIn(league: league) {
            // leave league
            activityOverlay.show()
            LeagueService.shared.leave(league: league) { [weak self] (result, error) in
                print("Leave league result \(String(describing: result)) error \(String(describing: error))")
                DispatchQueue.main.async {
                    self?.activityOverlay.hide()
                    if let error = error as NSError? {
                        self?.simpleAlert("Could not leave league", defaultMessage: nil, error: error)
                    }
                    // forces cell/button to reload
                    self?.notify(.PlayerLeaguesChanged, object: nil, userInfo: nil)
                    self?.joinLeagueCell?.reset()
                    self?.shareLeagueCell?.refresh()
                    
                    // when a user leaves a private league
                    if league.isPrivate {
                        NotificationService.shared.notify(.EventsChanged, object: nil, userInfo: nil)
                    }
                }
            }
        } else {
            // join league
            activityOverlay.show()
            LeagueService.shared.join(league: league) { [weak self] (result, error) in
                print("Join league result \(String(describing: result)) error \(String(describing: error))")
                DispatchQueue.main.async {
                    self?.activityOverlay.hide()
                    if let error = error as NSError? {
                        self?.simpleAlert("Could not join league", defaultMessage: nil, error: error)
                    }
                    // forces cell/button to reload
                    self?.notify(.PlayerLeaguesChanged, object: nil, userInfo: nil)
                    self?.joinLeagueCell?.reset()
                    self?.shareLeagueCell?.refresh()
                    
                    // when user joins a private league
                    if league.isPrivate {
                        NotificationService.shared.notify(.EventsChanged, object: nil, userInfo: nil)
                    }
                }
            }
        }
    }
    
    func promptForShare() {
        guard let league = league, let link = league.shareLink else {
            shareLeagueCell?.reset()
            simpleAlert("Sorry, can't share league", message: "There was an invalid share link or no share link.")
            return
        }
        let shareMethods = shareService.shareMethods

        // multiple share options are valid, so show options
        let alert = UIAlertController(title: "Invite to league", message: nil, preferredStyle: .actionSheet)
        if shareMethods.contains(.copy) {
            alert.addAction(UIAlertAction(title: "Copy link", style: .default, handler: {(action) in
                LoggingService.shared.log(event: LoggingEvent.ShareEventClicked, info: ["method": ShareMethod.copy.rawValue])
                UIPasteboard.general.string = link
                
                //Alert
                let displayString: String
                if let name = league.name, !name.isEmpty {
                    displayString = name
                } else {
                    displayString = "this league"
                }
                let alertController = UIAlertController(title: "", message: "Copied share link for \(displayString)", preferredStyle: .alert)
                alertController.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
                self.present(alertController, animated: true, completion: nil)
            }))
        }
        if shareMethods.contains(.contacts) {
            alert.addAction(UIAlertAction(title: "Send to contacts", style: .default, handler: {(action) in
                LoggingService.shared.log(event: LoggingEvent.ShareEventClicked, info: ["method": ShareMethod.contacts.rawValue])
                self.shareService.share(league: league, from: self)
            }))
        }
        if shareMethods.contains(.facebook) {
            alert.addAction(UIAlertAction(title: "Share to Facebook", style: .default, handler: {(action) in
                LoggingService.shared.log(event: LoggingEvent.ShareEventClicked, info: ["method": ShareMethod.facebook.rawValue])
                self.shareService.shareToFacebook(link: league.shareLink, from: self)
            }))
        }
        if UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiom.pad, let cell = shareLeagueCell {
            alert.popoverPresentationController?.sourceView = cell
            alert.popoverPresentationController?.sourceRect = cell.button.frame
        }
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        present(alert, animated: true) {
            self.shareLeagueCell?.reset()
        }
    }
    
    func promptForSignup() {
        let alert = UIAlertController(title: "Login or Sign up", message: "Before joining this league, you need to join Panna Social Leagues.", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default, handler: {[weak self] (action) in
            SplashViewController.shared?.goToSignupLogin()
            LoggingService.shared.log(event: .SignupFromSharedLeague, info: ["action": "OK"])
            self?.joinLeagueCell?.reset()
        }))
        alert.addAction(UIAlertAction(title: "Not now", style: .cancel, handler: { _ in
            LoggingService.shared.log(event: .SignupFromSharedLeague, info: ["action": "Not now"])
            self.joinLeagueCell?.reset()
        }))
        present(alert, animated: true, completion: nil)
    }
}

extension LeagueViewController: SharingDelegate {
    func sharer(_ sharer: Sharing, didCompleteWithResults results: [String : Any]) {
        let alert = UIAlertController(title: "Success", message: "League shared!", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Ok", style: .default, handler: nil))
        
        self.present(alert, animated: true, completion: nil)
    }
    
    func sharer(_ sharer: Sharing, didFailWithError error: Error) {
        print("Error: \(String(describing: error))")
        simpleAlert("Could not share", defaultMessage: "League invite could not be sent at this time.", error: error as NSError?)
    }
    
    func sharerDidCancel(_ sharer: Sharing) {
        print("User cancelled sharing.")
    }
}

// MARK: - FeedItems
extension LeagueViewController {
    func setupFeedInput() {
        // setup keyboard accessories
        let keyboardDoneButtonView = UIToolbar()
        keyboardDoneButtonView.sizeToFit()
        keyboardDoneButtonView.barStyle = UIBarStyle.black
        keyboardDoneButtonView.tintColor = UIColor.white
        let clearBtn: UIBarButtonItem = UIBarButtonItem(title: "Clear", style: .done, target: self, action: #selector(clear))
        
        keyboardDoneButtonView.setItems([clearBtn], animated: true)
        inputMessage.inputAccessoryView = keyboardDoneButtonView
        inputMessage.delegate = self
        
        buttonImage.setImage(buttonImage.image(for: .normal)?.withRenderingMode(.alwaysTemplate), for: .normal)
    }
    
    @objc func send() {
        guard let league = self.league else { return }
        self.activityOverlay.show()
        FeedService.shared.post(leagueId: league.id, message: self.inputMessage.text, image: feedItemPhoto) { [weak self] (error) in
            print("Done with error \(String(describing: error))")
            DispatchQueue.main.async {
                self?.clear()
                self?.activityOverlay.hide()
                self?.tableView.reloadData()
            }
        }
    }
    
    @objc func clear() {
        inputMessage.text = nil
        if let polaroid = UIImage(named: "polaroid") {
            buttonImage.setImage(polaroid.withRenderingMode(.alwaysTemplate), for: .normal)
        }
        feedItemPhoto = nil
        view.endEditing(true)
    }
    
    @IBAction fileprivate func didClickButton(_ sender: UIButton) {
        if sender == buttonSend {
            send()
        } else if sender == buttonImage {
            promptForImage()
        }
    }
    
    fileprivate func promptForImage() {
        self.view.endEditing(true)
        cameraHelper.takeOrSelectPhoto(from: self, fromView: buttonImage)
    }
}

// MARK: Camera
extension LeagueViewController: CameraHelperDelegate {
    func didCancelSelection() {
        print("Did not edit image")
        if let polaroid = UIImage(named: "polaroid") {
            buttonImage.setImage(polaroid.withRenderingMode(.alwaysTemplate), for: .normal)
        }
        feedItemPhoto = nil
    }
    
    func didCancelPicker() {
        print("Did not select image")
        dismiss(animated: true, completion: nil)
    }
    
    func didSelectPhoto(selected: UIImage?) {
        guard let image = selected else { return }
        let width = self.view.frame.size.width
        let height = width / image.size.width * image.size.height
        let size = CGSize(width: width, height: height)
        let resized = FirebaseImageService.resizeImage(image: image, newSize: size)
        feedItemPhoto = resized
        buttonImage.setImage(feedItemPhoto, for: .normal)
        dismiss(animated: true, completion: nil)
    }
}

extension LeagueViewController {
    @objc func handleEventDeepLink(_ notification: Notification?) {
        guard let userInfo = notification?.userInfo, let eventId = userInfo["eventId"] as? String else { return }
        guard let controller = UIStoryboard(name: "EventDetails", bundle: nil).instantiateViewController(withIdentifier: "EventDisplayViewController") as? EventDisplayViewController else { return }
        EventService.shared.withId(id: eventId) { [weak self] (event) in
            guard let event = event as? Event else { return }
            guard !event.isPast else {
                print("event is past, don't display")
                return
            }
            controller.event = event
            self?.present(controller, animated: true, completion: nil)
        }
    }
}
