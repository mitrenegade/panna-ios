//
//  PinpointViewController.swift
//  Panna
//
//  Created by Bobby Ren on 8/23/18.
//  Copyright © 2018 Bobby Ren. All rights reserved.
//

import UIKit
import MapKit
import RxSwift
import Balizinha

class PinpointViewController: UIViewController {
    @IBOutlet weak var mapView: MKMapView!
    @IBOutlet weak var labelPlaceName: UILabel!

    var name: String?
    var street: String?
    var city: String?
    var state: String?
    
    fileprivate var nameLocked: Bool = false
    
    @IBOutlet weak var buttonEdit: UIButton!
    
    fileprivate var externalSource: Bool = true
    var searchPlace: MKPlacemark? {
        didSet {
            if let place = searchPlace {
                externalSource = true // skips reverse geocode
                currentLocation = place.coordinate
                
                LocationService.shared.parseMKPlace(place, completion: { [weak self] (name, street, city, state) in
                    self?.name = name
                    self?.street = street
                    self?.city = city
                    self?.state = state
                    self?.refreshLabel()

                    self?.refreshLabel()
                })
            }
        }
    }
    var currentLocation: CLLocationCoordinate2D? {
        didSet {
            if let location = currentLocation {
                var span = mapView.region.span
                if externalSource {
                    span = MKCoordinateSpanMake(0.05, 0.05)
                }
                let region = MKCoordinateRegionMake(location, span)
                mapView.setRegion(region, animated: true)
            }
        }
    }
    
    @IBOutlet weak var pinView: UIView!
    
    var currentEvent: Balizinha.Event?
    fileprivate var disposeBag = DisposeBag()

    override func viewDidLoad() {
        super.viewDidLoad()

        LocationService.shared.startLocation(from: self)
        if let event = currentEvent, let lat = event.lat, let lon = event.lon {
            let location = CLLocationCoordinate2D(latitude: lat, longitude: lon)
            currentLocation = location
        } else {
            LocationService.shared.observedLocation.asObservable().subscribe(onNext: { [weak self] (state) in
                switch state {
                case .located(let location):
                    #if TARGET_OS_SIMULATOR
                    self?.externalSource = false // trigger a geocode in simulator. not needed on device
                    #endif
                    self?.currentLocation = location.coordinate
                    self?.disposeBag = DisposeBag()
                default:
                    print("still locating")
                }
            }).disposed(by: disposeBag)
        }
    }
    
    func refreshLabel() {
        var text: String = ""
        if let name = name {
            text = "\(name)\n"
        }
        if let street = street, street != name {
            text = "\(text)\(street)\n"
        }
        if let city = city, let state = state {
            text = "\(text)\(city), \(state)"
        } else if let city = city {
            text = "\(text)\(city)"
        } else if let state = state {
            text = "\(text)\(state)"
        }
        labelPlaceName.text = text
    }
}
extension PinpointViewController: MKMapViewDelegate {
    func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
        guard !externalSource else {
            externalSource = false
            return
        }
        
        let mapCenter = mapView.centerCoordinate
        print("mapview: region changed to \(mapCenter)")
        currentLocation = mapCenter
        
        doGeocode()
    }
    
    fileprivate func doGeocode() {
        guard let location = currentLocation else { return }
        LocationService.shared.findApplePlace(for: location) {[weak self] (place) in
            guard let place = place else { return }
            LocationService.shared.parseCLPlace(place, completion: { [weak self] (name, street, city, state) in
                if self?.nameLocked != true {
                    self?.name = name
                }
                self?.street = street
                self?.city = city
                self?.state = state
                self?.refreshLabel()
            })
        }
    }
    
    @IBAction func didClickEdit(_ sender: Any) {
        let alert = UIAlertController(title: "Venue Options", message: nil, preferredStyle: .actionSheet)
        alert.addAction(UIAlertAction(title: "Edit name", style: .default, handler: { (action) in
            self.editName()
        }))
        let title = nameLocked ? "Unlock name" : "Lock name"
        alert.addAction(UIAlertAction(title: title, style: .default, handler: { (action) in
            self.nameLocked = !self.nameLocked
        }))
        alert.addAction(UIAlertAction(title: "Close", style: .cancel) { (action) in
        })
        if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiom.pad)
        {
            alert.popoverPresentationController?.sourceView = self.view
            alert.popoverPresentationController?.sourceRect = buttonEdit.frame
        }
        self.present(alert, animated: true, completion: nil)
    }
    
    fileprivate func editName() {
        let alert = UIAlertController(title: "Please enter a promo code", message: nil, preferredStyle: .alert)
        alert.addTextField { (textField : UITextField!) -> Void in
            textField.placeholder = "Enter venue name"
            textField.text = self.name
        }
        alert.addAction(UIAlertAction(title: "OK", style: .default, handler: { (action) in
            if let textField = alert.textFields?[0], let name = textField.text {
                print("Manually changing name to \(name)")
                self.name = name
                self.refreshLabel()
            }
        }))
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        self.present(alert, animated: true)
    }
}
