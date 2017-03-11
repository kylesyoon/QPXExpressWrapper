//
//  ViewController.swift
//  QPXExpressWrapper
//
//  Created by Kyle Yoon on 05/17/2016.
//  Copyright (c) 2016 Kyle Yoon. All rights reserved.
//

import UIKit
import Foundation
import QPXExpressWrapper

class SearchViewController: UIViewController {

    let yourAPIKey = "AIzaSyA0FTpJ-ZvQzZJsBBVARlUXNYFiaYM-tS4"
    let searchURLString = "https://www.googleapis.com/qpxExpress/v1/trips/search"
    
    @IBOutlet var roundTripSegmentedControl: UISegmentedControl!
    @IBOutlet var originTextField: UITextField!
    @IBOutlet var destinationTextField: UITextField!
    @IBOutlet var departureDateButton: UIButton!
    @IBOutlet var returnDateButton: UIButton!
    @IBOutlet var adultCountStepper: UIStepper!
    @IBOutlet var adultCountLabel: UILabel!
    
    var departureDate: Date?
    var returnDate: Date?
    lazy var dateFormatter = DateFormatter()
    var adultCount = 1
    var isRoundTrip = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.returnDateButton.isHidden = true
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == DateViewController.departureDateSegueIdentifier || segue.identifier == DateViewController.returnDateSegueIdentifier {
            if let datePopoverNavController = segue.destination as? UINavigationController {
                if let dateViewController = datePopoverNavController.viewControllers.first as? DateViewController {
                    // Let VC know whether we tapped button for departure or return date
                    dateViewController.isDeparture = segue.identifier == DateViewController.departureDateSegueIdentifier
                    dateViewController.delegate = self
                }
                datePopoverNavController.preferredContentSize = CGSize(width: self.view.frame.width, height: self.view.frame.size.height / 4)
                if let datePresentationController = datePopoverNavController.popoverPresentationController {
                    datePresentationController.delegate = self
                    datePresentationController.permittedArrowDirections = UIPopoverArrowDirection.up
                    if let dateButton = sender as? UIButton {
                        datePresentationController.sourceRect = dateButton.frame
                        datePresentationController.sourceView = dateButton
                    }
                }
            }
        }
    }
    
    fileprivate func tripRequest() -> TripRequest? {
        guard let origin = self.originTextField.text,
            let destination = self.destinationTextField.text,
            let departureDate = self.departureDate else {
                // Show error for incomplete fields
                return nil
        }
        
        let departureTripSlice = TripRequestSlice(origin: origin, 
                                                  destination: destination,
                                                  date: departureDate)
        var requestTripSlices = [departureTripSlice]
        
        if let returnDate = self.returnDate, isRoundTrip {
            let returnTripSlice = TripRequestSlice(origin: destination,
                                                   destination: origin,
                                                   date: returnDate)
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
    
    fileprivate func query() {
        guard
            let tripRequest = self.tripRequest(),
            var searchURLComponents = URLComponents(string: self.searchURLString) else {
            return
        }
        
        let keyQueryItem = URLQueryItem(name: "key", value: self.yourAPIKey)
        searchURLComponents.queryItems = [keyQueryItem]
        
        guard let searchURL = searchURLComponents.url else {
            return
        }
        
        var request = URLRequest(url: searchURL)
        request.httpMethod = "POST"
        
        guard
            let requestBody = tripRequest.toJSON(),
            let json = try? JSONSerialization.data(withJSONObject: requestBody, options: .prettyPrinted) else {
            return
        }
        request.httpBody = json
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        
        let task = URLSession.shared.dataTask(with: request) {
            data, response, error in
            guard let data = data else {
                print("No data")
                return
            }
            
            do {
                guard let jsonDict = try JSONSerialization.jsonObject(with: data, options: .allowFragments) as? [String: AnyObject] else {
                    return
                }
                guard let searchResults = SearchResults(json: jsonDict) else {
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
    
    @IBAction func valueDidChangeForAdultCountStepper(_ stepper: UIStepper) {
        self.adultCountLabel.text = "Adults: \(Int(stepper.value))"
        self.adultCount = Int(stepper.value)
    }
    
    @IBAction func valueDidChangeForSegmentedControl(_ control: UISegmentedControl) {
        self.returnDateButton.isHidden = control.selectedSegmentIndex == 0
    }
    
    @IBAction func didTapSearchButton(_ sender: AnyObject) {
        self.query()
    }

}

extension SearchViewController: DateViewControllerDelegate {
    
    func dateViewController(_ dateViewController: DateViewController, didTapDoneWithDate date: Date) {
        if dateViewController.isDeparture {
            self.departureDate = date
            self.departureDateButton.setTitle(self.dateFormatter.presentableDate(fromDate: date), for: UIControlState())
            // If the user selects a date later than the return date they've specified, then clear return date
            if let returnDate = self.returnDate {
                if  date.compare(returnDate) == .orderedDescending {
                    self.returnDate = nil
                    self.returnDateButton.setTitle(NSLocalizedString("Return Date", comment: "Return Date"), for: UIControlState())
                }
            }
        } else {
            self.returnDate = date
            self.returnDateButton.setTitle(self.dateFormatter.presentableDate(fromDate: date), for: UIControlState())
            // If the user selects a date earlier than the departure date they've specified, then clear departure date
            if let departureDate = self.departureDate {
                if date.compare(departureDate) == .orderedAscending {
                    // If the return date is earlier than the departure date, do nothing.
                    self.departureDate = nil
                    self.departureDateButton.setTitle(NSLocalizedString("Departure Date", comment: "Departure Date"), for: UIControlState())
                }
            }
        }
    }
    
}

extension SearchViewController: UIPopoverPresentationControllerDelegate {
    
    func adaptivePresentationStyle(for controller: UIPresentationController) -> UIModalPresentationStyle {
        return .none
    }
    
}

extension DateFormatter {
    
    func presentableDate(fromDate date: Date) -> String {
        self.dateFormat = "MMM'.' dd',' yy"
        return self.string(from: date)
    }
    
    func presentableTime(fromDate date: Date) -> String {
        let usTwelveHourLocale = Locale(identifier: "en_US_POSIX")
        self.locale = usTwelveHourLocale // Investigate what this locale does
        self.dateFormat = "hh':'mm a"
        return self.string(from: date)
    }
    
}
