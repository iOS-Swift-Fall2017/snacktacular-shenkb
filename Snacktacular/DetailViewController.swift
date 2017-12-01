//
//  DetailViewController.swift
//  Snacktacular
//
//  Created by Kaining on 11/30/17.
//  Copyright © 2017 Kaining. All rights reserved.
//

import UIKit
import CoreLocation
import MapKit
import GooglePlaces

class DetailViewController: UIViewController {
    @IBOutlet weak var placeNameField: UITextField!
    @IBOutlet weak var addressField: UITextField!
    @IBOutlet weak var mapView: MKMapView!
    
    var placeData: PlaceData?
    var locationManager: CLLocationManager!
    var currentLocation: CLLocation!
    var regionRadius = 1000.0 //1 km
    
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        mapView.delegate = self
        if let placeData = placeData {
            centerMap(mapLocation: placeData.coordinate, regionRadius: regionRadius)
            mapView.removeAnnotations(mapView.annotations)
            mapView.addAnnotation(placeData)
            mapView.selectAnnotation(placeData, animated: true)
            updateUserInterface()
        } else {
            placeData = PlaceData(placeName: "", address: "", coordinate: CLLocationCoordinate2D(), postingUserID: "")
            getLocation()
        }
        placeNameField.becomeFirstResponder()
    }
    
    func updateUserInterface() {
        placeNameField.text = placeData!.placeName
        addressField.text = placeData!.address
    }
    //Center the map
    func centerMap(mapLocation: CLLocationCoordinate2D, regionRadius: CLLocationDistance) {
        let region = MKCoordinateRegionMakeWithDistance(mapLocation, regionRadius, regionRadius)
        mapView.setRegion(region, animated: true)
    }
    
    //Return trip from detail to the list
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        placeData?.placeName = placeNameField.text!
        placeData?.address = addressField.text!
    }
    
    //Alert Code
    func showAlert(title: String, message: String) {
        let alertControler = UIAlertController(title: title, message: message, preferredStyle: .alert)
        let alertAction = UIAlertAction(title: "OK", style: .default, handler: nil)
        alertControler.addAction(alertAction)
        present(alertControler, animated: true, completion: nil)
    }
    
    //Mark: Cancel Button Code
    @IBAction func cancelButtonPressed(_ sender: UIBarButtonItem) {
        let isPressingInAddMode = presentingViewController is UINavigationController
        if isPressingInAddMode {
            dismiss(animated: true, completion: nil)
        } else {
            navigationController?.popViewController(animated: true)
        }
    }
    
    @IBAction func lookupButtonPressed(_ sender: UIBarButtonItem) {
        let autocompleteController = GMSAutocompleteViewController()
        autocompleteController.delegate = self
        present(autocompleteController, animated: true, completion: nil)
    }
}

extension DetailViewController: CLLocationManagerDelegate {
    
    func getLocation() {
        locationManager = CLLocationManager()
        locationManager.delegate = self
    }
    
    func handleLocationAuthorizationStatus(status: CLAuthorizationStatus) {
        switch status {
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            locationManager.requestLocation()
        case .denied:
            showAlertToPrivacySettings(title: "User has not authorized location services", message: "Select 'Settings' below to open device settings and enable location services for this app.")
        case .restricted:
            showAlert(title: "Location services denied", message: "It may be that parental controls are restricting location use in this app.")
        }
    }
    
    func showAlertToPrivacySettings(title: String, message: String) {
        let alertControler = UIAlertController(title: title, message: message, preferredStyle: .alert)
        
        guard let settingsURL = URL(string: UIApplicationOpenSettingsURLString) else {
            print("Somthing went wrong of getting the settingOPenSettingsURLString")
            return
        }
        let settingAction  = UIAlertAction(title: "Settings", style: .default) {
            value in UIApplication.shared.open(settingsURL, options: [:], completionHandler: nil)
        }
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel, handler: nil)
        alertControler.addAction(cancelAction)
        alertControler.addAction(settingAction)
        present(alertControler, animated: true, completion: nil)
    }
    
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        handleLocationAuthorizationStatus(status: status)
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        let geoCoder = CLGeocoder()
        currentLocation = locations.last
        let currentLatitude = currentLocation.coordinate.latitude
        let currentLongitude = currentLocation.coordinate.longitude
        geoCoder.reverseGeocodeLocation(currentLocation, completionHandler: {
            placemarks, error in
            if placemarks != nil {
                let placemark = placemarks?.last
                self.placeData?.placeName = (placemark?.name)!
                self.placeData?.address = placemark?.thoroughfare ?? "unknown" //?? if the first part is unnill then put unknown in there, otherwise we use whatever we get back from the first part.
                self.placeData?.coordinate = CLLocationCoordinate2D(latitude: currentLatitude, longitude: currentLongitude)
                self.centerMap(mapLocation: (self.placeData?.coordinate)!, regionRadius: self.regionRadius)
                self.mapView.addAnnotation(self.placeData!)
                self.mapView.selectAnnotation(self.placeData!, animated: true)
                self.updateUserInterface()
            } else {
                print("Error retrieving place. Error code: \(error!)")
            }
        })
    }
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Fail To Get User Location.")
    }
}

extension DetailViewController:MKMapViewDelegate {
    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        let identifer = "Marker"
        var view: MKPinAnnotationView
        if let dequedView = mapView.dequeueReusableAnnotationView(withIdentifier: identifer) as? MKPinAnnotationView {
            dequedView.annotation = annotation
            view = dequedView
        } else {
            view = MKPinAnnotationView(annotation: annotation, reuseIdentifier: identifer)
            view.canShowCallout = true
            view.rightCalloutAccessoryView = UIButton(type: .custom)
        }
        return view
    }
}

extension DetailViewController: GMSAutocompleteViewControllerDelegate {
    
    // Handle the user's selection.
    func viewController(_ viewController: GMSAutocompleteViewController, didAutocompleteWith place: GMSPlace) {
        placeData?.placeName = place.name
        placeData?.coordinate = place.coordinate
        placeData?.address = place.formattedAddress ?? "unknown"
        centerMap(mapLocation: (placeData?.coordinate)!, regionRadius: regionRadius)
        mapView.removeAnnotations(mapView.annotations)
        mapView.addAnnotation(self.placeData!)
        mapView.selectAnnotation(self.placeData!, animated: true)
        updateUserInterface()
        dismiss(animated: true, completion: nil)
    }
    
    func viewController(_ viewController: GMSAutocompleteViewController, didFailAutocompleteWithError error: Error) {
        // TODO: handle the error.
        print("Error: ", error.localizedDescription)
    }
    
    // User canceled the operation.
    func wasCancelled(_ viewController: GMSAutocompleteViewController) {
        dismiss(animated: true, completion: nil)
    }
    
    // Turn the network activity indicator on and off again.
    func didRequestAutocompletePredictions(_ viewController: GMSAutocompleteViewController) {
        UIApplication.shared.isNetworkActivityIndicatorVisible = true
    }
    
    func didUpdateAutocompletePredictions(_ viewController: GMSAutocompleteViewController) {
        UIApplication.shared.isNetworkActivityIndicatorVisible = false
    }
    
}
