//
//  ListViewController.swift
//  Balizinha Admin
//
//  Created by Bobby Ren on 2/12/18.
//  Copyright © 2018 RenderApps LLC. All rights reserved.
//

import UIKit
import FirebaseCore
import Balizinha
import FirebaseDatabase
import RenderCloud

class ListViewController: UIViewController {
    @IBOutlet weak var tableView: UITableView!
    var league: League?

    internal var refName: String {
        assertionFailure("Must be implemented")
        return ""
    }
    internal var baseRef: Reference {
        return firRef
    }
    var objects: [FirebaseBaseModel] = []

    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.tableView.rowHeight = UITableViewAutomaticDimension
        self.tableView.estimatedRowHeight = 44

        load()
    }

    func load() {
        let ref: Query
        ref = baseRef.child(path: refName).queryOrdered(by: "createdAt")
        ref.observeSingleValue() {[weak self] (snapshot) in
            guard snapshot.exists() else { return }
            if let allObjects = snapshot.allChildren {
                self?.objects.removeAll()
                for dict: Snapshot in allObjects {
                    if let object = self?.createObject(from: dict) {
                        self?.objects.append(object)
                    }
                }
                self?.objects.sort(by: { (p1, p2) -> Bool in
                    guard let t1 = p1.createdAt else { return false }
                    guard let t2 = p2.createdAt else { return true}
                    return t1 > t2
                })

                self?.reloadTable()
            }
        }
    }
    
    func reloadTable() {
        tableView.reloadData()
    }
    
    func createObject(from snapshot: Snapshot) -> FirebaseBaseModel? {
        return FirebaseBaseModel(snapshot: snapshot)
    }
}

extension ListViewController: UITableViewDataSource {
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return objects.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        return UITableViewCell()
    }
}

extension ListViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
    }
}