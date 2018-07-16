//
//  LeagueViewController.swift
//  Balizinha
//
//  Created by Bobby Ren on 6/24/18.
//  Copyright © 2018 Bobby Ren. All rights reserved.
//

import UIKit

class LeagueViewController: UIViewController {
    fileprivate enum Row { // TODO: make CaseIterable
        case title
        case join
        case tags
        case info
        case players
    }
    
    fileprivate var rows: [Row] = [.title, .join, .tags, .info, .players]
    
    @IBOutlet weak var tableView: UITableView!
    var tagView: ResizableTagView?
    
    var league: League?
    var players: [Player] = []
    var roster: [Membership]?
    
    weak var joinLeagueCell: JoinLeagueCell?
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        tableView.rowHeight = UITableViewAutomaticDimension
        tableView.estimatedRowHeight = 80
        
        loadRoster()
        
        if league?.info.isEmpty == true, let index = rows.index(of: .info){
            rows.remove(at: index)
        }
        
        listenFor(.PlayerLeaguesChanged, action: #selector(loadPlayerLeagues), object: nil)
    }
    
    func loadRoster() {
        guard let league = league else { return }
        LeagueService.shared.memberships(for: league) { [weak self] (results) in
            self?.roster = results
            self?.observePlayers()
        }
    }
    
    @objc func loadPlayerLeagues() {
        // on join or leave, update the join button and also update player roster
        LeagueService.shared.refreshPlayerLeagues { [weak self] (results) in
            DispatchQueue.main.async {
                self?.joinLeagueCell?.reset()
            }
        }
//        BOBBY TODO: roster is not showing correctly after user joins league
//        BOBBY TODO: leaguesViewController needs to listen and update too
        loadRoster()
    }
    
    func observePlayers() {
        guard let league = self.league else { return }
        players.removeAll()
        let dispatchGroup = DispatchGroup()
        for membership in roster ?? [] {
            let playerId = membership.playerId
            guard membership.isActive else { continue }
            dispatchGroup.enter()
            PlayerService.shared.withId(id: playerId, completion: {[weak self] (player) in
                if let player = player {
                    self?.players.append(player)
                    dispatchGroup.leave()
                }
            })
        }
        dispatchGroup.notify(queue: DispatchQueue.main) { [weak self] in
            if let index = self?.rows.index(of: .players) {
                DispatchQueue.main.async {
                    self?.tableView.reloadRows(at: [IndexPath(row: index, section: 0)], with: .automatic)
                }
            }
        }
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "toLeaguePlayers", let controller = segue.destination as? LeaguePlayersViewController {
            controller.league = league
            controller.delegate = self
            controller.roster = roster
        }
    }
}

extension LeagueViewController: UITableViewDataSource {
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return rows.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch rows[indexPath.row] {
        case .title:
            let cell = tableView.dequeueReusableCell(withIdentifier: "LeagueTitleCell", for: indexPath) as! LeagueTitleCell
            cell.selectionStyle = .none
            cell.configure(league: league)
            return cell
        case .join:
            let cell = tableView.dequeueReusableCell(withIdentifier: "JoinLeagueCell", for: indexPath) as! JoinLeagueCell
            cell.selectionStyle = .none
            cell.delegate = self
            cell.configure(league: league)
            joinLeagueCell = cell
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
            cell.roster = roster
            cell.configure(players: players)
            return cell
        }
    }
}

extension LeagueViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        if let index = rows.index(of: .tags), index == indexPath.row {
            inputTag()
        }
    }
}

extension LeagueViewController: PlayersScrollViewDelegate {
    func didSelectPlayer(player: Player) {
        guard let playerController = UIStoryboard(name: "Account", bundle: nil).instantiateViewController(withIdentifier: "PlayerViewController") as? PlayerViewController else { return }
        
        playerController.player = player
        self.navigationController?.pushViewController(playerController, animated: true)
    }
}

extension LeagueViewController: LeaguePlayersDelegate {
    func didUpdateRoster() {
        loadRoster()
    }

    func goToAddPlayers() {
        performSegue(withIdentifier: "toLeaguePlayers", sender: nil)
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
                print("adding tag \(tag)")
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

extension LeagueViewController: JoinLeagueDelegate {
    func clickedJoinLeague(_ league: League) {
        print("Joining league \(league)")
        if LeagueService.shared.playerIsIn(league: league) {
            // leave league
            // BOBBY TODO: add leave league
            print("You cannot leave league! muhahaha")
            joinLeagueCell?.reset()
        } else {
            // join league
            LeagueService.shared.join(league: league) { [weak self] (result, error) in
                print("Join league result \(result) error \(error)")
                DispatchQueue.main.async {
                    self?.notify(.PlayerLeaguesChanged, object: nil, userInfo: nil)
                }
            }
        }
    }
}
