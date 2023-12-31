//
//  LeaguesViewController.swift
//  Balizinha
//
//  Created by Ren, Bobby on 4/30/18.
//  Copyright © 2018 Bobby Ren. All rights reserved.
//

import UIKit
import Balizinha
import Crashlytics

class LeaguesViewController: UIViewController {

    @IBOutlet weak var tableView: UITableView!
    var playerLeagues: [League] = []
    var otherLeagues: [League] = []
    
    var isLoading: Bool = true
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        navigationItem.title = "Leagues"
        
        let profileButton = UIButton(type: .custom)
        profileButton.setImage(UIImage.init(named: "hamburger4-square30")?.withRenderingMode(.alwaysTemplate), for: .normal)
        profileButton.addTarget(self, action: #selector(didClickProfile(_:)), for: .touchUpInside)
        profileButton.frame = CGRect(x: 0, y: 0, width: 30, height: 30)
        navigationItem.leftBarButtonItem = UIBarButtonItem(customView: profileButton)
        let infoButton = UIButton(type: .infoLight)
        infoButton.addTarget(self, action: #selector(didClickInfo(_:)), for: .touchUpInside)
        navigationItem.rightBarButtonItem = UIBarButtonItem(customView: infoButton)

        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 80

        listenFor(.PlayerLeaguesChanged, action: #selector(loadData), object: nil)

        // deeplink actions available from this controller
        self.listenFor(NotificationType.GoToAccountDeepLink, action: #selector(didClickProfile(_:)), object: nil)

        loadData()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        // came here from a deeplink; handle any other destination
        if let accountDestination: DeeplinkType.AccountActions = DeepLinkService.shared.accountDestination {
            switch accountDestination {
            case .profile:
                didClickProfile(self)
            case .payments:
                didClickProfile(self)
            }
        }
    }
    
    @objc fileprivate func didClickProfile(_ sender: Any) {
        print("Go to Account")
        guard let controller = UIStoryboard(name: "Account", bundle: nil).instantiateViewController(withIdentifier: "AccountViewController") as? AccountViewController else { return }
        let nav = UINavigationController(rootViewController: controller)
        controller.navigationItem.leftBarButtonItem = UIBarButtonItem(image: UIImage(named: "iconClose30"), style: .plain, target: self, action: #selector(self.dismissProfile))
        present(nav, animated: true) {
        }
    }
    
    @objc fileprivate func dismissProfile() {
        dismiss(animated: true, completion: nil)
    }
    
    @objc fileprivate func didClickInfo(_ sender: Any) {
        performSegue(withIdentifier: "toLeaguesInfo", sender: nil)
    }
    
    @objc fileprivate func loadData() {
        guard !AIRPLANE_MODE else {
            let league = MockService.mockLeague()
            playerLeagues = [league]
            isLoading = false
            reloadTableData()
            return
        }
        guard let player = PlayerService.shared.current.value else { return }
        
        otherLeagues.removeAll()
        playerLeagues.removeAll()
        
        isLoading = true
        
        let dispatchGroup = DispatchGroup()
        
        dispatchGroup.enter()
        var leagueIds: [String] = []
        LeagueService.shared.leagueMemberships(for: player) { (roster) in
            if let roster = roster {
                let ids = roster.compactMap({ (id, membership) -> String? in
                    if membership != Membership.Status.none {
                        return id
                    }
                    return nil
                })
                leagueIds.append(contentsOf: ids)
            }
            dispatchGroup.leave()
            print("User leagues received: \(leagueIds)")
        }
        
        dispatchGroup.enter()
        LeagueService.shared.getLeagues { [weak self] (leagues) in
            self?.otherLeagues.append(contentsOf: leagues)
            dispatchGroup.leave()
            print("All leagues received: \(leagues.count)")
        }
        
        dispatchGroup.notify(queue: DispatchQueue.main) { [weak self] in
            guard let weakself = self else { return }
            let sorted = weakself.otherLeagues.sorted() {
                guard let c1 = $0.createdAt else { return false }
                guard let c2 = $1.createdAt else { return true }
                return c1 < c2
            }
            weakself.playerLeagues = sorted.filter() {
                return leagueIds.contains($0.id)
            }
            weakself.otherLeagues = sorted.filter() {
                return !leagueIds.contains($0.id)
            }
            
            DispatchQueue.main.async {
                weakself.isLoading = false
                weakself.reloadTableData()
            }
        }
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "toLeague", let league = sender as? League, let nav = segue.destination as? UINavigationController, let controller = nav.viewControllers[0] as? LeagueViewController {
            controller.league = league
        }
    }
}

extension LeaguesViewController: UITableViewDataSource {
    fileprivate func reloadTableData() {
        tableView.reloadData()
    }

    func numberOfSections(in tableView: UITableView) -> Int {
        guard !isLoading else {
            return 1
        }
        return 2
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        guard !isLoading else {
            return 1
        }
        
        if section == 0 {
            return playerLeagues.count
        } else if section == 1 {
            return otherLeagues.count
        }
        return 0
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard !isLoading else {
            let cell = tableView.dequeueReusableCell(withIdentifier: "LoadingCell", for: indexPath)
            return cell
        }
        let cell : LeagueCell = tableView.dequeueReusableCell(withIdentifier: "LeagueCell", for: indexPath) as! LeagueCell
        let row = indexPath.row
        let section = indexPath.section
        if section == 0 {
            let league = playerLeagues[row]
            cell.configure(league: league)
        } else if section == 1 {
            let league = otherLeagues[row]
            cell.configure(league: league)
        }
        return cell
    }
    
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        if section == 0 && playerLeagues.isEmpty {
            return 0
        }
        if section == 1 && otherLeagues.isEmpty {
            return 0
        }
        
        return 40
    }
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        if section == 0 {
            return playerLeagues.isEmpty ? nil : "Your leagues"
        }
        if section == 1 {
            return otherLeagues.isEmpty ? nil : "Other leagues"
        }
        return nil
    }
}

extension LeaguesViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: false)
        guard !isLoading else { return }
        var league: League?

        // go to league info
        if indexPath.section == 0 {
            guard indexPath.row < playerLeagues.count else { return }
            league = playerLeagues[indexPath.row]
        } else if indexPath.section == 1 {
            guard indexPath.row < otherLeagues.count else { return }
            league = otherLeagues[indexPath.row]
        } else {
            return // this can't happen
        }

        performSegue(withIdentifier: "toLeague", sender: league)
    }
}
