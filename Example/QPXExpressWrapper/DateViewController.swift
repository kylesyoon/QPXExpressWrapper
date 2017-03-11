//
//  DateViewController.swift
//  Flights
//
//  Created by Kyle Yoon on 2/29/16.
//  Copyright © 2016 Kyle Yoon. All rights reserved.
//

import UIKit

protocol DateViewControllerDelegate {
    
    func dateViewController(_ dateViewController: DateViewController, didTapDoneWithDate date: Date)
    
}

class DateViewController: UIViewController {
    
    static let departureDateSegueIdentifier = "departureDateSegueIdentifier"
    static let returnDateSegueIdentifier = "returnDateSegueIdentifier"
    
    var isDeparture: Bool = true
    var delegate: DateViewControllerDelegate?
    
    @IBOutlet var datePicker: UIDatePicker!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.datePicker.minimumDate = Date()
    }
    
    @IBAction func didTapDoneButton(_ sender: AnyObject) {
        if let delegate = self.delegate {
            delegate.dateViewController(self,
                didTapDoneWithDate: self.datePicker.date)
        }
        self.dismiss(animated: true, completion: nil)
    }
    
}
