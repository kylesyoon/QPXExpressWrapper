//
//  ViewController.swift
//  QPXExpressWrapper
//
//  Created by Kyle Yoon on 05/17/2016.
//  Copyright (c) 2016 Kyle Yoon. All rights reserved.
//

import UIKit
import QPXExpressWrapper

class SearchViewController: UIViewController {

    let yourAPIKey = "[YOUR API KEY]"
    let searchURLString = "https://www.googleapis.com/qpxExpress/v1/trips/search"
    
    @IBOutlet var roundTripSegmentedControl: UISegmentedControl!
    @IBOutlet var originTextField: UITextField!
    @IBOutlet var destinationTextField: UITextField!
    @IBOutlet var departureDateButton: UIButton!
    @IBOutlet var returnDateButton: UIButton!
    @IBOutlet var adultCountStepper: UIStepper!
    @IBOutlet var adultCountLabel: UILabel!
    
    var departureDate: NSDate?
    var returnDate: NSDate?
    lazy var dateFormatter = NSDateFormatter()
    var adultCount = 1
    var isRoundTrip = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.returnDateButton.hidden = true
    }
    
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        if segue.identifier == DateViewController.departureDateSegueIdentifier || segue.identifier == DateViewController.returnDateSegueIdentifier {
            if let datePopoverNavController = segue.destinationViewController as? UINavigationController {
                if let dateViewController = datePopoverNavController.viewControllers.first as? DateViewController {
                    // Let VC know whether we tapped button for departure or return date
                    dateViewController.isDeparture = segue.identifier == DateViewController.departureDateSegueIdentifier
                    dateViewController.delegate = self
                }
                datePopoverNavController.preferredContentSize = CGSizeMake(CGRectGetWidth(self.view.frame), self.view.frame.size.height / 4)
                if let datePresentationController = datePopoverNavController.popoverPresentationController {
                    datePresentationController.delegate = self
                    datePresentationController.permittedArrowDirections = UIPopoverArrowDirection.Up
                    if let dateButton = sender as? UIButton {
                        datePresentationController.sourceRect = dateButton.frame
                        datePresentationController.sourceView = dateButton
                    }
                }
            }
        }
    }
    
    private func tripRequest() -> TripRequest? {
        guard let origin = self.originTextField.text,
            destination = self.destinationTextField.text,
            departureDate = self.departureDate else {
                // Show error for incomplete fields
                return nil
        }
        
        let departureTripSlice = TripRequestSlice(origin: origin,
                                                  destination: destination,
                                                  date: departureDate,
                                                  maxStops: nil,
                                                  maxConnectionDuration: nil,
                                                  preferredCabin: nil,
                                                  permittedDepartureTime: nil,
                                                  permittedCarrier: nil,
                                                  alliance: nil,
                                                  prohibitedCarrier: nil)
        var requestTripSlices = [departureTripSlice]
        
        if let returnDate = self.returnDate where isRoundTrip {
            let returnTripSlice = TripRequestSlice(origin: destination,
                                                   destination: origin,
                                                   date: returnDate, 
                                                   maxStops: nil, 
                                                   maxConnectionDuration: nil, 
                                                   preferredCabin: nil, 
                                                   permittedDepartureTime: nil, 
                                                   permittedCarrier: nil, 
                                                   alliance: nil, 
                                                   prohibitedCarrier: nil)
            requestTripSlices.append(returnTripSlice)
        }
        
        let requestPassengers = TripRequestPassengers(adultCount: self.adultCount,
                                                      childCount: nil,
                                                      infantInLapCount: nil,
                                                      infantInSeatCount: nil,
                                                      seniorCount: nil)
        
        return TripRequest(passengers: requestPassengers,
                           slice: requestTripSlices,
                           maxPrice: nil,
                           saleCountry: nil,
                           refundable: nil,
                           solutions: nil)
    }
    
    private func query() {
        guard let tripRequest = self.tripRequest(),
            searchURLComponents = NSURLComponents(string: self.searchURLString) else {
            return
        }
        
        let keyQueryItem = NSURLQueryItem(name: "key", value: self.yourAPIKey)
        searchURLComponents.queryItems = [keyQueryItem]
        
        guard let searchURL = searchURLComponents.URL else {
            return
        }
        
        let request = NSMutableURLRequest(URL: searchURL)
        request.HTTPMethod = "POST"
        
        let requestBody = tripRequest.jsonDict()
        guard let json = try? NSJSONSerialization.dataWithJSONObject(requestBody, options: .PrettyPrinted) else {
            return
        }
        request.HTTPBody = json
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        
        let task = NSURLSession.sharedSession().dataTaskWithRequest(request) {
            data, response, error in
            guard let data = data else {
                print("No data")
                return
            }
            
            do {
                guard let jsonDict = try NSJSONSerialization.JSONObjectWithData(data, options: .AllowFragments) as? [String: AnyObject] else {
                    return
                }
                guard let searchResults = SearchResults.decode(jsonDict) else {
                    print("Not a SearchResults JSON dictionary")
                    return
                }
                
                print("\(searchResults)")
            } catch {
                print("Serialization error")
            }
        }
        
        task.resume()
    }
    
    @IBAction func valueDidChangeForAdultCountStepper(stepper: UIStepper) {
        self.adultCountLabel.text = "Adults: \(Int(stepper.value))"
        self.adultCount = Int(stepper.value)
    }
    
    @IBAction func valueDidChangeForSegmentedControl(control: UISegmentedControl) {
        self.returnDateButton.hidden = control.selectedSegmentIndex == 0
    }
    
    @IBAction func didTapSearchButton(sender: AnyObject) {
        self.query()
    }

}

extension SearchViewController: DateViewControllerDelegate {
    
    func dateViewController(dateViewController: DateViewController, didTapDoneWithDate date: NSDate) {
        if dateViewController.isDeparture {
            self.departureDate = date
            self.departureDateButton.setTitle(self.dateFormatter.presentableDate(fromDate: date), forState: .Normal)
            // If the user selects a date later than the return date they've specified, then clear return date
            if let returnDate = self.returnDate {
                if  date.compare(returnDate) == .OrderedDescending {
                    self.returnDate = nil
                    self.returnDateButton.setTitle(NSLocalizedString("Return Date", comment: "Return Date"), forState: .Normal)
                }
            }
        } else {
            self.returnDate = date
            self.returnDateButton.setTitle(self.dateFormatter.presentableDate(fromDate: date), forState: .Normal)
            // If the user selects a date earlier than the departure date they've specified, then clear departure date
            if let departureDate = self.departureDate {
                if date.compare(departureDate) == .OrderedAscending {
                    // If the return date is earlier than the departure date, do nothing.
                    self.departureDate = nil
                    self.departureDateButton.setTitle(NSLocalizedString("Departure Date", comment: "Departure Date"), forState: .Normal)
                }
            }
        }
    }
    
}

extension SearchViewController: UIPopoverPresentationControllerDelegate {
    
    func adaptivePresentationStyleForPresentationController(controller: UIPresentationController) -> UIModalPresentationStyle {
        return .None
    }
    
}

extension NSDateFormatter {
    
    func presentableDate(fromDate date: NSDate) -> String {
        self.dateFormat = "MMM'.' dd',' yy"
        return self.stringFromDate(date)
    }
    
    func presentableTime(fromDate date: NSDate) -> String {
        let usTwelveHourLocale = NSLocale(localeIdentifier: "en_US_POSIX")
        self.locale = usTwelveHourLocale // Investigate what this locale does
        self.dateFormat = "hh':'mm a"
        return self.stringFromDate(date)
    }
    
}
