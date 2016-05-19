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
    @IBOutlet var passengerCountSlider: UISlider!
    @IBOutlet var passengerCountLabel: UILabel!
    
    var departureDate: NSDate?
    var returnDate: NSDate?
    lazy var dateFormatter = NSDateFormatter()
    
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        if segue.identifier == DateViewController.departureDateSegueIdentifier || segue.identifier == DateViewController.returnDateSegueIdentifier {
            if let datePopoverNavController = segue.destinationViewController as? UINavigationController {
                if let dateViewController = datePopoverNavController.viewControllers.first as? DateViewController {
                    // Let VC know whether we tapped button for departure or return date
                    dateViewController.isDeparture = segue.identifier == DateViewController.departureDateSegueIdentifier
                    dateViewController.delegate = self
                }
                datePopoverNavController.preferredContentSize = CGSizeMake(CGRectGetWidth(self.view.frame), self.view.frame.size.height / 4)
                let datePresentationController = datePopoverNavController.popoverPresentationController
                datePresentationController?.delegate = self
                datePresentationController?.permittedArrowDirections = UIPopoverArrowDirection.Up
                if let dateButton = sender as? UIButton {
                    datePresentationController?.sourceRect = dateButton.frame
                    datePresentationController?.sourceView = dateButton
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
        
        let requestPassengers = TripRequestPassengers(adultCount: Int(self.passengerCountSlider.value),
                                                      childCount: nil,
                                                      infantInLapCount: nil,
                                                      infantInSeatCount: nil,
                                                      seniorCount: nil)
        
        return TripRequest(passengers: requestPassengers,
                           slice: [departureTripSlice],
                           maxPrice: nil,
                           saleCountry: nil,
                           refundable: nil,
                           solutions: nil)
    }
    
    private func query() {
        guard let tripRequest = self.tripRequest() else {
            return
        }
        
        let requestBody = tripRequest.jsonDict()
        
        if let searchURL = NSURL(string: self.searchURLString) {
            let request = NSMutableURLRequest(URL: searchURL)
            request.HTTPMethod = "POST"
            
            guard let json = try? NSJSONSerialization.dataWithJSONObject(requestBody, options: .PrettyPrinted) else {
                return
            }
            request.HTTPBody = json
            request.addValue("application/json", forHTTPHeaderField: "Content-Type")
            request.addValue("application/json", forHTTPHeaderField: "Accept")
            
            let task = NSURLSession.sharedSession().dataTaskWithRequest(request) {
                data, response, error in
                if let data = data {
                    guard let responseObject = try? NSJSONSerialization.JSONObjectWithData(data, options: .AllowFragments) else {
                        return
                    }
                    print("\(responseObject)")
                }
            }
            task.resume()
        }
    }
    
    @IBAction func valueDidChangeForSlider(slider: UISlider) {
        let roundedValue = round(slider.value)
        slider.value = roundedValue
        self.passengerCountLabel.text = "\(roundedValue)"
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
