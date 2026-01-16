import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
    connect() {
        if (typeof google !== "undefined" && google.maps) {
            this.initAutocomplete();
        } else {
            this.waitForGoogleMaps();
        }
    }

    waitForGoogleMaps() {
        const checkInterval = setInterval(() => {
            if (typeof google !== "undefined" && google.maps) {
                clearInterval(checkInterval);
                this.initAutocomplete();
            }
        }, 100);

        // Safety timeout after 10 seconds
        setTimeout(() => clearInterval(checkInterval), 10000);
    }

    initAutocomplete() {
        console.log("Address Autocomplete Controller connected");
        const autocomplete = new google.maps.places.Autocomplete(this.element, {
            types: ["address"],
            fields: ["formatted_address", "geometry", "name"],
        });
        autocomplete.addListener("place_changed", () => {
            const place = autocomplete.getPlace();
            console.log(place);
        });
    }
}