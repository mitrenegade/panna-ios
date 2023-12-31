//
//  CreateEventTableViewController.swift
// Balizinha
//
//  Created by Tom Strissel on 5/19/16.
//  Copyright © 2016 Bobby Ren. All rights reserved.
//

import UIKit
import CoreLocation
import Balizinha
import RenderCloud
import RenderPay

protocol CreateEventDelegate: class {
    func eventsDidChange()
}

fileprivate enum Sections: Int {
    case photo = 0
    case details = 1
    case notes = 2
    case cancel = 3
}

fileprivate var FUTURE_DAYS = 90

class CreateEventViewController: UIViewController, UITextViewDelegate {
    private enum Options: String {
        case name = "Name"
        case type = "Event Type"
        case venue = "Venue"
        case videoUrl = "Video Conference"
        case day = "Day"
        case start = "Start Time"
        case end = "End Time"
        case recurrence = "Recurrence"
        case players = "Max Players"
        case payment = "Payment"
    }

    private var options: [Options]!
    var eventTypes: [Balizinha.Event.EventType] = [.other, .event3v3, .event4v4, .event5v5, .event6v6, .event7v7, .event11v11, .group, .social]
    
    var currentField : UITextField?
    var currentTextView : UITextView?
    
    var name: String?
    var type : Balizinha.Event.EventType?
    var venue: Venue?
    var videoUrl: String?
    var eventDate : Date? {
        didSet {
            if let eventDate = eventDate, let startTime = startTime {
                recurrenceToggleCell?.recurrenceStartDate = combineDateAndTime(eventDate, time: startTime)
            }
        }
    }
    var dateString: String?
    var startTime: Date? {
        didSet {
            if let eventDate = eventDate, let startTime = startTime {
                recurrenceToggleCell?.recurrenceStartDate = combineDateAndTime(eventDate, time: startTime)
            }
        }
    }
    var endTime: Date?
    var maxPlayers : UInt?
    var info : String?
    var paymentRequired: Bool = false
    var recurrence: Date.Recurrence = .none
    var recurrenceDate: Date?
    var amount: NSNumber?
    
    private var clonedDateRow: Int = -1
    
    var nameField: UITextField?
    var typeField: UITextField?
    var placeField: UITextField?
    var dayField: UITextField?
    var startField: UITextField?
    var endField: UITextField?
    var maxPlayersField: UITextField?
    var videoUrlField: UITextField?
    var descriptionTextView : UITextView?
    var amountField: UITextField?
    var paymentSwitch: UISwitch?
    weak var recurrenceToggleCell: RecurrenceToggleCell?

    var keyboardDoneButtonView: UIToolbar!
    var keyboardDoneButtonView2: UIToolbar!
    var keyboardHeight : CGFloat!
    
    @IBOutlet var tableView: UITableView!
    @IBOutlet var menuButton: UIBarButtonItem!
    @IBOutlet var saveButton: UIBarButtonItem!

    fileprivate let activityOverlay: ActivityIndicatorOverlay = ActivityIndicatorOverlay()

    var typePickerView: UIPickerView = UIPickerView()
    var numberPickerView: UIPickerView = UIPickerView()
    var datePickerView: UIPickerView = UIPickerView()
    var startTimePickerView: UIDatePicker = UIDatePicker()
    var endTimePickerView: UIDatePicker = UIDatePicker()
    var league: League?

    weak var delegate: CreateEventDelegate?
    
    var newEventImage: UIImage? // if user selects a new image or is cloning
    var currentEventUrl: String? // url used to display existing image
    var eventToEdit: Balizinha.Event? {
        didSet {
            cloneInfo(for: eventToEdit)
        }
    }
    var eventToClone: Balizinha.Event? {
        didSet {
            cloneInfo(for: eventToClone)
        }
    }
    var datesForPicker: [Date] = []
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.navigationItem.title = league?.name ?? "Create Event"
        if let _ = self.eventToEdit {
            self.navigationItem.title = "Edit Event"
        }
        
        options = [.name, .type, .venue, .videoUrl, .day, .start, .end, .recurrence, .players]
        if SettingsService.paymentRequired() {
            options.append(.payment)
        }
        if !SettingsService.useVideoLink, let index = options.firstIndex(of: .videoUrl) {
            options.remove(at: index)
        }
        // TODO: make recurrence feature flagged
        
        self.tableView.rowHeight = UITableView.automaticDimension
        self.tableView.estimatedRowHeight = 44
        
        self.setupPickers()
        self.setupTextFields()
        
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Save", style: .done, target: self, action: #selector(didClickSave(_:)))
        navigationItem.leftBarButtonItem = UIBarButtonItem(title: "Cancel", style: .plain, target: self, action: #selector(didClickCancel(_:)))
        
        if eventToEdit == nil && eventToClone == nil && CACHE_ORGANIZER_FAVORITE_LOCATION {
            self.loadCachedOrganizerFavorites()
        } else if let event = eventToEdit, event.isCancelled {
            // prompt to uncancel event right away
            promptForCancelDeleteEvent(event)
        }
        
        view.addSubview(activityOverlay)
    }

    override func viewWillAppear(_ animated: Bool) {
        NotificationCenter.default.addObserver(self, selector: #selector(CreateEventViewController.keyboardWillShow(_:)), name: UIResponder.keyboardWillShowNotification, object: nil)
    }

    override func viewWillDisappear(_ animated: Bool) {
        NotificationCenter.default.removeObserver(self)
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        activityOverlay.setup(frame: view.frame)
    }
    
    // used when editing or cloning an existing event
    fileprivate func cloneInfo(for event: Balizinha.Event?) {
        guard let event = event else { return }
        name = event.name
        type = event.type
        if event == eventToEdit {
            // only include date if event is being edited
            eventDate = eventToEdit?.startTime
            startTime = eventToEdit?.startTime
            endTime = eventToEdit?.endTime
        }
        maxPlayers = UInt(event.maxPlayers)
        info = event.info
        paymentRequired = event.paymentRequired
        recurrence = event.recurrence
        recurrenceDate = event.recurrenceEndDate
        
        amount = event.amount

        // this causes it to lock up. for now, a cloned event doesn't have to copy the venue
        if let venueId = event.venueId {
            placeField?.placeholder = "Loading..."
            VenueService.shared.withId(id: venueId) { [weak self] (result) in
                if let clonedVenue = result as? Venue {
                    DispatchQueue.main.async { [weak self] in
                        self?.didSelectVenue(clonedVenue)
                    }
                }
            }
        }
        videoUrl = event.validVideoUrl?.absoluteString

        if let leagueId = event.leagueId {
            LeagueService.shared.withId(id: leagueId) { [weak self] (league) in
                self?.league = league as? League
                // in case this takes time to load
                self?.refreshLeaguePhoto()
            }
        }
        
        FirebaseImageService().eventPhotoUrl(for: event) { [weak self] (url) in
            if let urlString = url?.absoluteString {
                if event == self?.eventToClone {
                    // load photo and store it in newEventImage since it will get saved as a new image
                    let manager = RAImageManager(imageView: nil)
                    manager.load(imageUrl: urlString, completion: { [weak self] (image) in
                        DispatchQueue.main.async {
                            self?.newEventImage = image
                            let indexPath = IndexPath(row: 0, section: Sections.photo.rawValue)
                            self?.tableView.reloadRows(at: [indexPath], with: .automatic)
                        }
                    })
                } else if event == self?.eventToEdit {
                    // save downloaded url just to display
                    self?.currentEventUrl = urlString
                    let indexPath = IndexPath(row: 0, section: Sections.photo.rawValue)
                    self?.tableView.reloadRows(at: [indexPath], with: .automatic)
                }
            }
        }
        
        // preselect picker values
        generatePickerDates() // picker dates must be set ahead of time
        if let startDate = event.startTime {
            startTime = event.startTime
            endTime = event.endTime
            for i in 0..<datesForPicker.count {
                let date = datesForPicker[i]
                if date.dateStringForPicker() == startDate.dateStringForPicker() {
                    clonedDateRow = i
                }
            }
        }
    }
    
    func setupPickers() {
        for picker in [typePickerView, numberPickerView, datePickerView] {
            picker.sizeToFit()
            picker.delegate = self
            picker.dataSource = self
        }
        
        self.startTimePickerView.datePickerMode = .time
        self.startTimePickerView.addTarget(self, action: #selector(timePickerValueChanged), for: .valueChanged)
        
        self.endTimePickerView.datePickerMode = .time
        self.endTimePickerView.addTarget(self, action: #selector(timePickerValueChanged), for: .valueChanged)

        for picker in [startTimePickerView, endTimePickerView] {
            picker.sizeToFit()
            picker.minuteInterval = 15
        }

        self.generatePickerDates()
        
        if clonedDateRow != -1 {
            datePickerView.selectRow(clonedDateRow, inComponent: 0, animated: true)
        }
    }
    
    func setupTextFields() {
        // textfield keyboard
        self.keyboardDoneButtonView = UIToolbar()
        keyboardDoneButtonView.sizeToFit()
        keyboardDoneButtonView.barStyle = UIBarStyle.default
        keyboardDoneButtonView.tintColor = UIColor.white
        let save: UIBarButtonItem = UIBarButtonItem(title: "Done", style: .done, target: self, action: #selector(CreateEventViewController.done))
        save.tintColor = self.view.tintColor
        
        let flex: UIBarButtonItem = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
        
        keyboardDoneButtonView.setItems([flex, save], animated: true)
        
        // textview keyboard
        self.keyboardDoneButtonView2 = UIToolbar()
        keyboardDoneButtonView2.sizeToFit()
        keyboardDoneButtonView2.barStyle = UIBarStyle.default
        keyboardDoneButtonView2.tintColor = UIColor.white
        let save2: UIBarButtonItem = UIBarButtonItem(title: "Done", style: .done, target: self.view, action: #selector(UIView.endEditing(_:)))
        save2.tintColor = self.view.tintColor
        keyboardDoneButtonView2.setItems([flex, save2], animated: true)
        
        if TESTING, eventToEdit == nil, eventToClone == nil {
            self.eventDate = Date()
            self.startTime = Date()+1800
            self.endTime = Date()+3600
            maxPlayers = 10
        }
    }
    
    fileprivate var leaguePhotoView: RAImageView?
    fileprivate lazy var photoHeaderView: UIView = {
        let view = UIView(frame: CGRect(x: 0, y: 0, width: self.view.frame.size.width, height: 100))
        view.backgroundColor = PannaUI.iconBackground
        view.clipsToBounds = true
        let photoView = RAImageView(frame: CGRect(x: view.frame.size.width / 2 - 40, y: 10, width: 80, height: 80))
        photoView.layer.cornerRadius = 5
        photoView.backgroundColor = .clear
        photoView.image = nil
        photoView.clipsToBounds = true
        view.addSubview(photoView)
        leaguePhotoView = photoView
        leaguePhotoView?.contentMode = .scaleAspectFill
        
        refreshLeaguePhoto()
        return view
    }()
    
    fileprivate func refreshLeaguePhoto() {
        if let leagueId = league?.id {
            FirebaseImageService().leaguePhotoUrl(with: leagueId) {[weak self] (url) in
                DispatchQueue.main.async {
                    if let url = url {
                        self?.leaguePhotoView?.imageUrl = url.absoluteString
                    } else {
                        self?.leaguePhotoView?.imageUrl = nil
                        self?.leaguePhotoView?.image = UIImage(named: "crest30")?.withRenderingMode(.alwaysTemplate)
                        self?.leaguePhotoView?.tintColor = UIColor.white
                    }
                }
            }
        }
    }

    fileprivate func loadCachedOrganizerFavorites() {
        if let name = DefaultsManager.shared.value(forKey: "organizerCachedName") as? String {
            self.name = name
        }
        if let venueId = DefaultsManager.shared.value(forKey: "organizerCachedVenueId") as? String {
            VenueService.shared.withId(id: venueId) { [weak self] (venue) in
                self?.venue = venue as? Venue
            }
        }
        if let type = DefaultsManager.shared.value(forKey: "organizerCachedType") as? String {
            self.type = Balizinha.Event.EventType(rawValue: type)
        }
        if let info = DefaultsManager.shared.value(forKey: "organizerCachedInfo") as? String {
            self.info = info
        }
    }
    
    fileprivate func cacheOrganizerFavorites() {
        if let name = name {
            DefaultsManager.shared.setValue(name, forKey: "organizerCachedName")
        } else {
            DefaultsManager.shared.setValue(nil, forKey: "organizerCachedName")
        }
        
        if let venue = venue {
            DefaultsManager.shared.setValue(venue.id, forKey: "organizerCachedVenueId")
        } else {
            DefaultsManager.shared.setValue(nil, forKey: "organizerCachedVenueId")
        }
        
        if let type = type {
            UserDefaults.standard.set(type.rawValue, forKey: "organizerCachedType")
        }
        if let info = info {
            UserDefaults.standard.set(info, forKey: "organizerCachedInfo")
        }
    }
    
    @IBAction func didClickSave(_ sender: AnyObject) {
        // in case user clicks save without clicking done first
        self.done()
        self.info = self.descriptionTextView?.text ?? eventToEdit?.info
        
        // either venue or video url must exist
        if Balizinha.Event.validUrl(videoUrl) == nil && venue == nil {
            self.simpleAlert("Invalid selection", message: "Please select a venue or add a video link")
            return
        }
        var venueName: String?
        var city: String?
        var state: String?
        if let venue = venue {
            guard let newName = venue.name ?? venue.street else {
                self.simpleAlert("Invalid selection", message: "Invalid name for selected venue")
                return
            }
            venueName = newName
            
            if !venue.isRemote {
                guard let newCity = venue.city else {
                    self.simpleAlert("Invalid selection", message: "Invalid city for selected venue")
                    return
                }
                guard let newState = venue.state else {
                    self.simpleAlert("Invalid selection", message: "Invalid state for selected venue")
                    return
                }
                    city = newCity
                    state = newState
            }
        }
        
        var newVideoUrl: String? = nil//Balizinha.Event.validUrl(videoUrl)?.absoluteString
        if let urlString = videoUrl, !urlString.isEmpty {
            if let url = Balizinha.Event.validUrl(urlString) {
                newVideoUrl = url.absoluteString
            } else {
                self.simpleAlert("Invalid video link", message: "Please check that you have entered the correct url.")
                return
            }
        }

        guard let eventDate = self.eventDate else {
            self.simpleAlert("Invalid selection", message: "Please select the event date")
            return
        }
        guard let startTime = self.startTime else {
            self.simpleAlert("Invalid selection", message: "Please select a start time")
            return
        }
        guard let endTime = self.endTime else {
            self.simpleAlert("Invalid selection", message: "Please select an end time")
            return
        }
        guard let maxPlayers = self.maxPlayers else {
            self.simpleAlert("Invalid selection", message: "Please select the number of players allowed")
            return
        }
        
        if paymentRequired && SettingsService.paymentRequired(){
            guard let amount = self.amount, amount.doubleValue > 0 else {
                self.simpleAlert("Invalid payment amount", message: "Please enter the amount required to play, or turn off the payment requirement.")
                return
            }
        }

        navigationItem.rightBarButtonItem?.isEnabled = false

        if CACHE_ORGANIZER_FAVORITE_LOCATION {
            self.cacheOrganizerFavorites()
        }

        let start = self.combineDateAndTime(eventDate, time: startTime)
        var end = self.combineDateAndTime(eventDate, time: endTime)
        // most like scenario is that endTime is past midnight so it gets interpreted as midnight of the day before.
        if end.timeIntervalSince(start) < 0 {
            end = end.addingTimeInterval(24*3600)
        }
        self.startTime = start
        self.endTime = end
        
        if let event = self.eventToEdit, var dict = event.dict {
            // event already exists: update/edit info
            dict["name"] = self.name ?? "Balizinha"
            dict["type"] = self.type?.rawValue
            dict["city"] = city
            dict["state"] = state
            dict["place"] = venueName
            dict["lat"] = venue?.lat
            dict["lon"] = venue?.lon
            dict["maxPlayers"] = maxPlayers
            dict["info"] = self.info
            dict["paymentRequired"] = self.paymentRequired
            if paymentRequired {
                dict["amount"] = self.amount
            }
            dict["recurrence"] = recurrence.rawValue
            if let date = recurrenceDate {
                dict["recurrenceEndDate"] = date.timeIntervalSince1970
            }
            if let venueId = venue?.id {
                dict["venueId"] = venueId
            }
            dict["videoUrl"] = newVideoUrl
            event.dict = dict
            event.firebaseRef?.updateChildValues(dict) // update all these values without multiple update calls

            // use the built in conversion for dates
            event.startTime = start
            event.endTime = end

            // update photo if it has been changed
            if let image = newEventImage {
                savePhoto(photo: image, event: event, completion: { url, id in
                    // no callback action
                    self.navigationController?.dismiss(animated: true, completion: {
                        // event updated - force reload
                        self.delegate?.eventsDidChange()
                    })
                })
            } else {
                self.navigationController?.dismiss(animated: true, completion: {
                    // event updated - force reload
                    self.delegate?.eventsDidChange()
                })
            }
        }
        else {
            activityOverlay.show()
            EventService.shared.createEvent(self.name ?? "Balizinha", type: self.type ?? .other, venue: venue, startTime: start, endTime: end, recurrence: self.recurrence, recurrenceEndDate: self.recurrenceDate, maxPlayers: maxPlayers, info: self.info, paymentRequired: self.paymentRequired, amount: self.amount, leagueId: league?.id, videoUrl: newVideoUrl, completion: { [weak self] (event, error) in
                
                DispatchQueue.main.async { [weak self] in
                    self?.activityOverlay.hide()
                    
                    guard let event = event else {
                        self?.simpleAlert("Could not create event", defaultMessage: "There was an error creating your event.", error: error)
                        self?.navigationItem.rightBarButtonItem?.isEnabled = true
                        return
                    }
                    
                    // update photo if it has been changed
                    if let image = self?.newEventImage {
                        self?.savePhoto(photo: image, event: event, completion: { url, id in
                            // no callback action
                            self?.navigationController?.dismiss(animated: true, completion: {
                                // event created
                                self?.delegate?.eventsDidChange()
                            })
                        })
                    } else {
                        let changed = Date.didDaylightSavingsChange(start, self?.recurrenceDate)
                        if changed {
                            self?.simpleAlert("Check event dates", message: "Your events have been created, but a change in Daylight Saving Time may affect some dates.", completion: {
                                self?.navigationController?.dismiss(animated: true, completion: {
                                    // event created
                                    self?.delegate?.eventsDidChange()
                                })
                            })
                            
                            // logging only
                            var info = ["start": start.dateString()]
                            if let end = self?.recurrenceDate {
                                info["end"] = end.dateString()
                            }
                            LoggingService.shared.log(event: .RecurringEventDaylightSavingsWarned, info: info)
                        } else {
                            self?.navigationController?.dismiss(animated: true, completion: {
                                // event created
                                self?.delegate?.eventsDidChange()
                            })
                        }
                    }
                }
            })
            
            if eventToClone != nil {
                LoggingService.shared.log(event: .ClonedEvent, info: nil)
            }
        }
    }
    
    @objc func didClickCancel(_ sender: Any) {
        self.navigationController?.dismiss(animated: true, completion: nil)
    }
}

extension CreateEventViewController: UITableViewDataSource, UITableViewDelegate {
    // MARK: - Table view data source

    func numberOfSections(in tableView: UITableView) -> Int {
        if let event = eventToEdit, event.userIsOrganizer(), CancelEventViewModel(event: event).shouldShow {
            return 4
        }
        return 3
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch section {
        case Sections.photo.rawValue: // photo
            return 1
        case Sections.details.rawValue: // details
            return options.count
        case Sections.notes.rawValue: // description
            return 1
        case Sections.cancel.rawValue:
            return 1
        default:
            return 0
        }
    }

    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        switch indexPath.section {
        case Sections.photo.rawValue:
            let cell: PhotoCell = tableView.dequeueReusableCell(withIdentifier: "photoCell", for: indexPath) as! PhotoCell
            if let photo = newEventImage {
                cell.photo = photo
            } else if let url = currentEventUrl {
                cell.url = url
            }
            return cell
        case Sections.details.rawValue:
            let cell : DetailCell
            switch options[indexPath.row] {
            case .venue, .name, .videoUrl:
                cell = tableView.dequeueReusableCell(withIdentifier: "cityCell", for: indexPath) as! DetailCell
                cell.valueTextField.delegate = self
                cell.valueTextField.inputAccessoryView = nil
                
                if options[indexPath.row] == .venue {
                    cell.valueTextField.placeholder = "Fenway Park"
                    self.placeField = cell.valueTextField
                    self.placeField?.text = venue?.name
                    self.placeField?.isUserInteractionEnabled = false
                } else if options[indexPath.row] == .name {
                    cell.valueTextField.placeholder = "Balizinha"
                    self.nameField = cell.valueTextField
                    self.nameField?.text = name
                    self.nameField?.isUserInteractionEnabled = true
                } else if options[indexPath.row] == .videoUrl {
                    cell.valueTextField.placeholder = "Click to add a url"
                    self.videoUrlField = cell.valueTextField
                    self.videoUrlField?.text = videoUrl
                    self.videoUrlField?.isUserInteractionEnabled = true
                    self.videoUrlField?.keyboardType = .URL
                }
            case .payment:
                let cell = tableView.dequeueReusableCell(withIdentifier: "PaymentToggleCell", for: indexPath) as! ToggleCell
                cell.input?.inputAccessoryView = keyboardDoneButtonView
                cell.delegate = self
                self.amountField = cell.input
                self.paymentSwitch = cell.switchToggle
                self.didToggle(cell.switchToggle, isOn: paymentRequired)
                return cell
            case .recurrence:
                let cell = tableView.dequeueReusableCell(withIdentifier: "RecurrenceToggleCell", for: indexPath) as! RecurrenceToggleCell
                cell.recurrenceDelegate = self
                cell.presenter = self
                cell.loggingService = LoggingService.shared
                
                cell.recurrence = recurrence
                cell.recurrenceStartDate = startTime
                cell.recurrenceEndDate = recurrenceDate
                cell.refresh()
                recurrenceToggleCell = cell
                return cell
            default:
                cell = tableView.dequeueReusableCell(withIdentifier: "detailCell", for: indexPath) as! DetailCell
                
                cell.valueTextField.isUserInteractionEnabled = false;
                cell.valueTextField.delegate = self
                
                switch options[indexPath.row] {
                case .type:
                    self.typeField = cell.valueTextField
                    self.typeField?.inputView = self.typePickerView
                    cell.valueTextField.inputAccessoryView = self.keyboardDoneButtonView2
                    
                    if let type = type, let index = self.eventTypes.firstIndex(of: type) {
                        if eventTypes[index] == .other {
                            typeField!.text = "Select event type"
                        } else {
                            typeField!.text = eventTypes[index].rawValue
                        }
                    }
                case .day:
                    self.dayField = cell.valueTextField
                    self.dayField?.inputView = self.datePickerView
                    cell.valueTextField.inputAccessoryView = self.keyboardDoneButtonView
                    if let eventDate = eventDate {
                        self.dayField?.text = eventDate.dateStringForPicker()
                    }
                case .start:
                    self.startField = cell.valueTextField
                    self.startField?.inputView = self.startTimePickerView
                    cell.valueTextField.inputAccessoryView = self.keyboardDoneButtonView
                    if let date = startTime {
                        self.startField?.text = date.timeStringForPicker()
                    }
                case .end:
                    self.endField = cell.valueTextField
                    self.endField?.inputView = self.endTimePickerView
                    cell.valueTextField.inputAccessoryView = self.keyboardDoneButtonView
                    if let date = endTime {
                        self.endField?.text = date.timeStringForPicker()
                    }
                case .players:
                    self.maxPlayersField = cell.valueTextField
                    self.maxPlayersField?.inputView = self.numberPickerView
                    cell.valueTextField.inputAccessoryView = self.keyboardDoneButtonView2

                    if let max = maxPlayers {
                        self.maxPlayersField?.text = "\(max)"
                    }
                default:
                    break
                }

            }
            cell.labelAttribute.text = options[indexPath.row].rawValue

            return cell

        case Sections.notes.rawValue:
            let cell : DescriptionCell = tableView.dequeueReusableCell(withIdentifier: "descriptionCell", for: indexPath) as! DescriptionCell
            self.descriptionTextView = cell.descriptionTextView
            cell.descriptionTextView.delegate = self
            
            cell.descriptionTextView.inputAccessoryView = self.keyboardDoneButtonView2
            
            if let notes = info {
                cell.descriptionTextView.text = notes
            }

            return cell
        case Sections.cancel.rawValue:
            guard let event = eventToEdit, let cell = tableView.dequeueReusableCell(withIdentifier: "CancelEventCell", for: indexPath) as? CancelEventCell else { return UITableViewCell() }
            cell.configure(event)
            return cell
        default:
            let cell = tableView.dequeueReusableCell(withIdentifier: "detailCell", for: indexPath)
            return cell
            
        }

    }

    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let label = UILabel(frame: CGRect(x: 16, y: 0, width: self.view.frame.size.width - 16, height: 40))
        let view = UIView(frame: CGRect(x: 0, y: 0, width: self.view.frame.size.width, height: 40))
        view.backgroundColor = PannaUI.tableHeaderBackground
        label.backgroundColor = UIColor.clear
        label.font = UIFont.montserratMedium(size: 18)
        label.textColor = PannaUI.tableHeaderText
        view.clipsToBounds = true

        switch section {
        case Sections.photo.rawValue:
            return photoHeaderView
        case Sections.details.rawValue:
            label.text = "Details"
        case Sections.notes.rawValue:
            label.text = "Description"
        case Sections.cancel.rawValue:
            view.backgroundColor = .white
            label.text = ""
        default:
            return nil;
        }
        view.addSubview(label)
        return view
    }
    
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        if section == Sections.photo.rawValue {
            return 100
        }
        if section == Sections.cancel.rawValue {
            return 0.1
        }
        return 40
    }
    
    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        return 0.1
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        switch indexPath.section {
        case Sections.photo.rawValue:
            let alert = UIAlertController(title: "Select image", message: nil, preferredStyle: .actionSheet)
            if UIImagePickerController.isSourceTypeAvailable(.camera) {
                alert.addAction(UIAlertAction(title: "Camera", style: .default, handler: { (action) in
                    self.selectPhoto(camera: true)
                }))
            }
            alert.addAction(UIAlertAction(title: "Photo album", style: .default, handler: { (action) in
                self.selectPhoto(camera: false)
            }))
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel) { (action) in
            })
            
            if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiom.pad), let cell = self.tableView.cellForRow(at: indexPath) as? PhotoCell {
                alert.popoverPresentationController?.sourceView = cell
                alert.popoverPresentationController?.sourceRect = cell.imagePlus.frame
            }

            self.present(alert, animated: true, completion: nil)
        case Sections.details.rawValue:
            if currentField != nil{
                currentField!.resignFirstResponder()
            }
            
            let textField: UITextField?
            switch options[indexPath.row] {
            case .name:
                textField = self.nameField
            case .type:
                textField = self.typeField
                typePickerView.reloadAllComponents()
            case .venue:
                textField = self.placeField
            case .day:
                textField = self.dayField
            case .start:
                textField = self.startField
            case .end:
                textField = self.endField
            case .players:
                textField = self.maxPlayersField
                print("Tapped number of players")
                numberPickerView.reloadAllComponents()
            default:
                textField = nil
            }
            if textField != self.placeField {
                textField?.isUserInteractionEnabled = true
            }
            textField?.becomeFirstResponder()
            currentField = textField
            
            if options[indexPath.row] == .venue {
                performSegue(withIdentifier: "toLocationSearch", sender: nil)
            }
        case Sections.cancel.rawValue:
            guard let event = eventToEdit else { return }

            promptForCancelDeleteEvent(event)
        default:
            break
        }
        
    }
    
    @objc func done() {
        // on button click on toolbar for day, time pickers
        self.currentField?.resignFirstResponder()
        self.updateLabel()
    }
    
    func updateLabel(){
        guard currentField != nil else { return }
        
        if (currentField == self.typeField) {
            let selectedRow = self.typePickerView.selectedRow(inComponent: 0)
            self.type = eventTypes[selectedRow]
            if eventTypes[selectedRow] == .other {
                currentField!.text = "Select event type"
            } else {
                currentField!.text = self.eventTypes[selectedRow].rawValue
            }
        } else if (currentField == self.maxPlayersField) { //selected max players
            self.maxPlayers = UInt(self.pickerView(self.numberPickerView, titleForRow: self.numberPickerView.selectedRow(inComponent: 0), forComponent: 0)!)
            if let maxPlayers = self.maxPlayers {
                currentField!.text = "\(maxPlayers)"
            }
        }
        // comes from clicking on done button. may not have the text yet
        else if currentField == self.startField {
            self.timePickerValueChanged(self.startTimePickerView)
        }
        else if currentField == self.endField {
            self.timePickerValueChanged(self.endTimePickerView)
        }
        else if currentField == self.dayField {
            self.datePickerValueChanged(self.datePickerView)
        }
        else if currentField == self.amountField {
            if let formattedAmount = EventService.amountNumber(from: self.amountField?.text) {
                self.amount = formattedAmount
                if let string = EventService.amountString(from: formattedAmount) {
                    self.amountField?.text = string
                }
            }
            else {
                self.revertAmount()
            }
        }
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "toLocationSearch", let controller = segue.destination as? VenuesListViewController {
            controller.delegate = self
//            if let eventToEdit = eventToEdit, let venueId = eventToEdit.venueId {
//                VenueService.shared.withId(id: venueId) { (venue) in
//                    controller.currentVenue = venue
//                }
//            }
        }
    }
}

// MARK: Delete
extension CreateEventViewController {
    private func promptForCancelDeleteEvent(_ event: Balizinha.Event) {
        let viewModel = CancelEventViewModel(event: event)
        let title = "Event options"
        let alert = UIAlertController(title: title, message: nil, preferredStyle: .actionSheet)
        alert.addAction(UIAlertAction(title: viewModel.cancelOptionText, style: .default) { [weak self] (action) in
            self?.doCancel(event)
        })
        alert.addAction(UIAlertAction(title: viewModel.deleteOptionText, style: .default) { [weak self] (action) in
            self?.doDelete(event)
        })
        alert.addAction(UIAlertAction(title: "Never mind", style: .cancel) { (action) in
        })
        present(alert, animated: true, completion: nil)
    }

    private func doCancel(_ event: Balizinha.Event) {
        let viewModel = CancelEventViewModel(event: event)
        let alert = UIAlertController(title: viewModel.alertTitle, message: viewModel.cancelMessage, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: viewModel.cancelConfirmButtonText, style: .default, handler: { (action) in
            let cancel = !event.isCancelled
            self.activityOverlay.show()
            EventService.shared.cancelEvent(event, isCancelled: cancel, completion: { [weak self] (error) in
                DispatchQueue.main.async {
                    self?.activityOverlay.hide()
                    if let error = error as NSError? {
                        let title = cancel ? "cancel" : "uncancel"
                        self?.simpleAlert("Could not \(title) event", defaultMessage: nil, error: error)
                        LoggingService.shared.log(event: .CancelEvent, info: ["eventId": event.id, "cancelled": cancel, "error": error.localizedDescription])
                    } else {
                        LoggingService.shared.log(event: .CancelEvent, info: ["eventId": event.id, "cancelled": cancel])
                        self?.delegate?.eventsDidChange()
                        self?.navigationController?.dismiss(animated: true, completion: nil)
                    }
                }
            })
        }))
        alert.addAction(UIAlertAction(title: viewModel.alertCancelText, style: .cancel, handler: nil))
        self.present(alert, animated: true, completion: nil)
    }
    
    private func doDelete(_ event: Balizinha.Event) {
        let viewModel = CancelEventViewModel(event: event)
        let alert = UIAlertController(title: viewModel.alertTitle, message: viewModel.deleteMessage, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: viewModel.deleteConfirmButtonText, style: .default, handler: { (action) in
            self.activityOverlay.show()
            EventService.shared.deleteEvent(event) { [weak self] (error) in
                DispatchQueue.main.async {
                    self?.activityOverlay.hide()
                    if let error = error as NSError? {
                        print("Event \(event.id) delete with error \(error)")
                        let title = "Could not delete event"
                        self?.simpleAlert(title, defaultMessage: "There was an error with deletion.", error: error)
                        LoggingService.shared.log(event: .DeleteEvent, info: ["eventId": event.id, "error": error.localizedDescription])
                    } else {
                        self?.delegate?.eventsDidChange()
                        self?.navigationController?.dismiss(animated: true, completion: nil)
                        LoggingService.shared.log(event: .DeleteEvent, info: ["eventId": event.id])
                    }
                }
            }
        }))
        alert.addAction(UIAlertAction(title: viewModel.alertCancelText, style: .cancel) { (action) in
        })
        present(alert, animated: true, completion: nil)
    }
}

// MARK: PickerView
extension CreateEventViewController: UIPickerViewDataSource, UIPickerViewDelegate {
    //MARK: - Delegates and data sources
    //MARK: Data Sources
    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        return 1
    }
    
    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        //print("Reloaded number of rows")
        if pickerView == self.typePickerView {
            return eventTypes.count
        }
        else if pickerView == self.numberPickerView {
            return 64
        }
        return FUTURE_DAYS // datePickerView: default 3 months
    }
    
    // The data to return for the row and component (column) that's being passed in
    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        //print("Reloaded components")
        
        if pickerView == self.typePickerView {
            if eventTypes[row] == .other {
                return "Select event type"
            }
            return eventTypes[row].rawValue
        }
        else if pickerView == self.datePickerView {
            if row < self.datesForPicker.count {
                return self.datesForPicker[row].dateStringForPicker()
            }
        }
        if row == 0 {
            return "Select a number"
        }
        return "\(row + 1)"
    }
    
    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        // let user pick more dates and click done
        guard pickerView != self.datePickerView else { return }
        guard let currentField = currentField else { return }
        guard row > 0 else { return }

        updateLabel()
        currentField.isUserInteractionEnabled = false
        currentField.resignFirstResponder()
    }
    
    func datePickerValueChanged(_ sender:UIPickerView) {
        let row = sender.selectedRow(inComponent: 0)
        guard row < self.datesForPicker.count else { return }
        if currentField == dayField {
            eventDate = self.datesForPicker[row]
            dateString = self.datesForPicker[row].dateStringForPicker()
            currentField?.text = dateString
        }
    }
    
    @objc func timePickerValueChanged(_ sender:UIDatePicker) {
        currentField!.text = sender.date.timeStringForPicker()
        if (sender == startTimePickerView) {
            self.startTime = sender.clampedDate
        } else if (sender == endTimePickerView) {
            self.endTime = sender.clampedDate
        }
    }
}

extension CreateEventViewController: UITextFieldDelegate {
    // MARK: - UITextFieldDelegate
    func textFieldDidBeginEditing(_ textField: UITextField) {
        currentField = textField
        
        if currentField == startField {
            startTimePickerView.date = startTime ?? Date()
            startTimePickerView.date = startTimePickerView.futureClampedDate
        }
        else if currentField == endField {
            endTimePickerView.date = Date()
            if let time = startTime {
                endTimePickerView.date = time.addingTimeInterval(3600)
            }
            endTimePickerView.date = endTimePickerView.futureClampedDate
        }
        
        if textField == amountField, let index = options.firstIndex(of: .payment) {
            tableView.scrollToRow(at: IndexPath(row: index, section: Sections.details.rawValue), at: .top, animated: true)
        }
    }
    
    func textFieldDidEndEditing(_ textField: UITextField) {
        if textField == self.nameField {
            let oldName = self.name
            self.name = textField.text
            
            // logging to track event changes
            if let event = eventToEdit, let old = oldName, let newName = textField.text {
                LoggingService.shared.log(event: .RenameEvent, info: ["oldName": old, "newName": newName, "eventId": event.id])
            }
        } else if textField == self.videoUrlField {
            self.videoUrl = textField.text
        } else if textField == self.amountField, let newAmount = EventService.amountNumber(from: textField.text) {
            var title = "Payment amount"
            var shouldShow = false
            if newAmount.doubleValue < 1 {
                title = "Low payment amount"
                shouldShow = true
            }
            else if newAmount.doubleValue >= 20 {
                title = "High payment amount"
                shouldShow = true
            }
            if shouldShow, let string = EventService.amountString(from: newAmount) {
                let oldAmount = self.amount
                let alert = UIAlertController(title: title, message: "Are you sure you want the payment per player to be \(string)?", preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: { (action) in
                    self.amount = oldAmount // because of timing issue, self.amount gets set to new amount by now
                    self.revertAmount()
                }))
                alert.addAction(UIAlertAction(title: "Amount is correct", style: .default, handler: { (action) in
                    
                }))
                self.present(alert, animated: true, completion: nil)
            }
            
            // logging to track event changes
            if let event = eventToEdit {
                LoggingService.shared.log(event: .ChangeEventPaymentAmount, info: ["eventId": event.id, "oldAmount": self.amount ?? 0, "newAmount": newAmount])
            }
        }
    }
    
    // MARK: -UITextViewDelegate
    func textViewDidBeginEditing(_ textView: UITextView) {
       self.tableView.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: self.keyboardHeight, right: 0)
        
        let indexPath = IndexPath(row: 0, section: Sections.notes.rawValue)
        self.tableView.scrollToRow(at: indexPath, at: .bottom, animated: true)
    }
    
    func textViewDidEndEditing(_ textView: UITextView) {
        self.tableView.contentInset = UIEdgeInsets.zero
        self.info = self.descriptionTextView!.text
    }
    
    // MARK - Keyboard
    @objc func keyboardWillShow(_ notification: Notification) {
        let userInfo:NSDictionary = notification.userInfo! as NSDictionary
        let keyboardFrame:NSValue = userInfo.value(forKey: UIResponder.keyboardFrameEndUserInfoKey) as! NSValue
        let keyboardRectangle = keyboardFrame.cgRectValue
        let keyboardHeight = keyboardRectangle.height
        
        self.keyboardHeight = keyboardHeight
    }
    
    // MARK - Date concatenation
    func combineDateAndTime(_ day: Date, time: Date) -> Date {
        
        let calendar = Calendar.current
        let dateComponents = (calendar as NSCalendar).components([.year, .month, .day], from: day)
        let timeComponents = (calendar as NSCalendar).components([.hour, .minute, .second], from: time)
        
        var components = DateComponents()
        components.year = dateComponents.year
        components.month = dateComponents.month
        components.day = dateComponents.day
        components.hour = timeComponents.hour
        components.minute = timeComponents.minute
        components.second = timeComponents.second
        
        let newDate = calendar.date(from: components)!
        return newDate
    }
}

// photo
extension CreateEventViewController: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    func selectPhoto(camera: Bool) {
        self.view.endEditing(true)
        
        let picker = UIImagePickerController()
        picker.delegate = self
        picker.allowsEditing = true
        
        picker.view.backgroundColor = .blue
        
        if camera, UIImagePickerController.isSourceTypeAvailable(.camera) {
            picker.sourceType = .camera
            picker.cameraCaptureMode = .photo
            picker.showsCameraControls = true
        } else {
            if UIImagePickerController.isSourceTypeAvailable(.photoLibrary) {
                picker.sourceType = .photoLibrary
            }
            else {
                picker.sourceType = .savedPhotosAlbum
            }
            picker.navigationBar.isTranslucent = false
            picker.navigationBar.barTintColor = PannaUI.navBarTint
        }
        
        self.present(picker, animated: true)
    }
    
    override var prefersStatusBarHidden: Bool {
        return false
    }

    func didTakePhoto(image: UIImage) {
        dismissCamera {
            self.newEventImage = image
            let indexPath = IndexPath(row: 0, section: 0)
            self.tableView.reloadRows(at: [indexPath], with: .automatic)
        }
    }
    
    func dismissCamera(completion: (()->Void)? = nil) {
        dismiss(animated: true, completion: completion)
    }
    
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        let img = info[UIImagePickerController.InfoKey.editedImage] ?? info[UIImagePickerController.InfoKey.originalImage]
        guard let photo = img as? UIImage else { return }
        self.didTakePhoto(image: photo)
    }
    
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        self.dismissCamera()
    }
    
    func savePhoto(photo: UIImage, event: Balizinha.Event?, completion: @escaping ((_ url: String?, _ photoId: String?)->Void)) {
        let alert = UIAlertController(title: "Progress", message: "Please wait until photo uploads", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Close", style: .cancel) { (action) in
        })
        self.present(alert, animated: true, completion: nil)
        
        let resized = FirebaseImageService.resizeImageForEvent(image: photo) ?? photo
        let id = event?.id ?? PannaServiceManager.apiService.uniqueId()
        FirebaseImageService.uploadImage(image: resized, type: .event, uid: id, progressHandler: { (percent) in
            alert.title = "Progress: \(Int(percent*100))%"
        }, completion: { (url) in
            alert.dismiss(animated: true, completion: nil)
            completion(url, id) // returns url for photoUrl, and id for photoId
        })
    }
}

// MARK: custom weekday pickers
extension CreateEventViewController {
    func generatePickerDates() {
        guard self.datesForPicker.count == 0 else { return }
        
        for row in 0..<FUTURE_DAYS {
            let date = Date().addingTimeInterval(3600*24*TimeInterval(row))
            datesForPicker.append(date)
        }
    }
}

// MARK: ToggleCell
extension CreateEventViewController: ToggleCellDelegate {
    func didToggle(_ toggle: UISwitch, isOn: Bool) {
        if toggle == paymentSwitch {
            paymentRequired = isOn
            self.paymentSwitch?.isOn = isOn
            self.amountField?.isEnabled = isOn
            self.amountField?.isHidden = !isOn
            if isOn {
                self.revertAmount()
            }
            
            // logging to track event changes
            if let event = eventToEdit {
                LoggingService.shared.log(event: .ToggleEventPaymentRequired, info: ["eventId": event.id, "paymentRequired": paymentRequired])
            }
        }
    }

    func revertAmount() {
        self.amountField?.text = EventService.amountString(from: self.amount)
    }
}

extension CreateEventViewController: RecurrenceCellDelegate {
    func didSelectRecurrence(_ recurrence: Date.Recurrence, _ recurrenceEndDate: Date?) {
        self.recurrence = recurrence
        recurrenceDate = recurrenceEndDate
        if let index = options.firstIndex(of: .recurrence) {
            let indexPath = IndexPath(row: index, section: Sections.details.rawValue)
            tableView.reloadRows(at: [indexPath], with: .automatic)
        }
    }
}

// MARK: VenuesListDelegate
extension CreateEventViewController: VenuesListDelegate {
    func didCancelSelection() {
        
    }
    
    func didCreateVenue(_ venue: Venue) {
        
    }
    
    func didSelectVenue(_ newVenue: Venue) {
        if let location = newVenue.name {
            placeField?.text = location
        }
        else if let street = newVenue.street {
            placeField?.text = street
        }

        venue = newVenue
        navigationController?.popToViewController(self, animated: true)
    }
}
