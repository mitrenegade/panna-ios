//
//  AccountViewController.swift
//  Balizinha
//
//  Created by Tom Strissel on 5/19/16.
//  Copyright © 2016 Bobby Ren. All rights reserved.
//

import UIKit
import FBSDKLoginKit

class AccountViewController: UITableViewController {
    
    let menuOptions = ["Edit profile", "Push notifications", "Promo program", "Version", /*"Bundle", */"Logout"]
    var service = EventService.shared

    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.navigationItem.title = "Account"

    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return menuOptions.count
    }

    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {

        switch menuOptions[indexPath.row] {
        case "Push notifications":
            let cell : PushTableViewCell = tableView.dequeueReusableCell(withIdentifier: "push", for: indexPath) as! PushTableViewCell
            cell.labelPush.text = menuOptions[indexPath.row]
            cell.selectionStyle = .none
            cell.accessoryType = .none
            cell.refresh()
            return cell
            
        case "Edit profile", "Logout":
            let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
            cell.textLabel?.text = menuOptions[indexPath.row]
            cell.accessoryType = .disclosureIndicator
            return cell
            
        case "Version":
            let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
            let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
            let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String
            cell.textLabel?.text = "Version: \(version ?? "unknown") (\(build ?? "unknown"))"
            cell.accessoryType = .none
            return cell
            
        case "Bundle":
            let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
            let bundle = Bundle.main.infoDictionary?["CFBundleIdentifier"] as? String
            cell.textLabel?.text = "Bundle id: \(bundle ?? "unknown")"
            cell.accessoryType = .none
            return cell
            
        case "Promo program":
            let cell = tableView.dequeueReusableCell(withIdentifier: "PromoCell", for: indexPath) as! PromoCell
            cell.configure()
            return cell
            
        default:
            return UITableViewCell()
        }
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        self.tableView.deselectRow(at: indexPath, animated: true)
       
        switch menuOptions[indexPath.row] {
        case "Edit profile":
            self.performSegue(withIdentifier: "ToEditPlayerInfo", sender: nil)
        case "Push notifications":
            break
        case "Logout":
            self.logout()
        case "Promo program":
            if let player = PlayerService.shared.current, player.promotionId == nil {
                self.addPromotion()
            }
        default:
            break
        }
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "ToEditPlayerInfo" {
            if let nav = segue.destination as? UINavigationController, let controller = nav.viewControllers[0] as? PlayerInfoViewController {
                controller.player = PlayerService.shared.current
                controller.isCreatingPlayer = false
            }
        }
    }
    
    private func logout() {
        try! firAuth.signOut()
        EventService.resetOnLogout() // force new listeners
        PlayerService.resetOnLogout()
        OrganizerService.resetOnLogout()
        FBSDKLoginManager().logOut()
        self.notify(.LogoutSuccess, object: nil, userInfo: nil)
    }
    
    // MARK: - Promotions
    func addPromotion() {
        guard let current = PlayerService.shared.current else { return }
        let alert = UIAlertController(title: "Please enter a promo code", message: nil, preferredStyle: .alert)
        alert.addTextField { (textField : UITextField!) -> Void in
            textField.placeholder = "Promo code"
        }
        alert.addAction(UIAlertAction(title: "OK", style: .default, handler: { (action) in
            if let textField = alert.textFields?[0], let promo = textField.text {
                print("Using promo code \(promo)")
                PromotionService.shared.withId(id: promo, completion: { (promotion) in
                    if let promotion = promotion {
                        print("\(promotion)")
                        current.promotionId = promotion.id
                        self.tableView.reloadData()
                    }
                    else {
                        self.simpleAlert("Invalid promo code", message: "The promo code \(promo) seems to be invalid.")
                    }
                })
            }
        }))
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        self.present(alert, animated: true)
    }
}
