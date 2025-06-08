import SwiftUI
import MapKit

struct MapAnnotationItem: Identifiable {
    let id = UUID()
    let mapItem: MKMapItem
}

struct LocationPickerView: View {
    @Environment(\.presentationMode) var presentationMode
    @State private var searchText = ""
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 55.7558, longitude: 37.6173),
        span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
    )
    @State private var selectedPlace: MKMapItem?
    @Binding var selectedLocation: TaskItem.Location?
    
    var body: some View {
        NavigationView {
            VStack {
                Map(coordinateRegion: $region,
                    showsUserLocation: true,
                    userTrackingMode: .constant(.none),
                    annotationItems: selectedPlace.map { [MapAnnotationItem(mapItem: $0)] } ?? []) { item in
                    MapMarker(coordinate: item.mapItem.placemark.coordinate)
                }
                .frame(height: 300)
                
                List {
                    Section(header: Text("search".localized)) {
                        TextField("enter_address".localized, text: $searchText)
                            .onChange(of: searchText) { newValue in
                                searchLocation(query: newValue)
                            }
                    }
                    
                    if let place = selectedPlace {
                        Section(header: Text("selected_place".localized)) {
                            VStack(alignment: .leading) {
                                Text(place.name ?? "")
                                    .font(.headline)
                                Text(place.placemark.title ?? "")
                                    .font(.subheadline)
                                    .foregroundColor(.gray)
                            }
                        }
                    }
                }
            }
            .navigationTitle("location_picker".localized)
            .navigationBarItems(
                leading: Button("cancel".localized) {
                    presentationMode.wrappedValue.dismiss()
                },
                trailing: Button("save".localized) {
                    if let place = selectedPlace {
                        selectedLocation = TaskItem.Location(
                            latitude: place.placemark.coordinate.latitude,
                            longitude: place.placemark.coordinate.longitude,
                            address: place.placemark.title ?? ""
                        )
                    }
                    presentationMode.wrappedValue.dismiss()
                }
                .disabled(selectedPlace == nil)
            )
        }
    }
    
    private func searchLocation(query: String) {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query
        request.region = region
        
        let search = MKLocalSearch(request: request)
        search.start { response, error in
            guard let response = response else { return }
            if let firstItem = response.mapItems.first {
                selectedPlace = firstItem
                region.center = firstItem.placemark.coordinate
            }
        }
    }
} 