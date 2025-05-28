/* Overview of mapView components:
 
 App on appear:  List of sites and pilots loaded
 
 MapView:
    Site list and pilot list passed in as environment object
    Map built using MKMapViewWrapper
    On appear, timer is started to periodically update annotations
    updateMapAnnotations is called on appear, change of scene, or change of map parameters to manage CustomMapAnnotation structure
    Publish any changes to pilotTracksViewModel
 
 updateMapAnnotations manages the CustomMapAnnotation [CustomMapAnnotation] structure:
    Removes all existing CustomMapAnnotations
    Based on which map layers are active:
        Fetches source data (calls fetchTrackingData for pilot tracks, latest readings for station readings, etc.)
            Update pilot tracks to pilotTracksViewModel
        Appends CustomMapAnnotations for active layers

*/

import SwiftUI
import MapKit
import Combine
import UIKit
import CoreGraphics
import CoreLocation
import Foundation

