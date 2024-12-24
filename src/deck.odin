package main

import "core:encoding/json"
import "core:os"

deck_load_json :: proc(path: string) -> Maybe(Deck) {
	data, err := os.read_entire_file_from_filename_or_err(path)
	if err != nil {
		log_red(err, "when reading", path)
		return nil
	}
	deck := Deck{}
	json_err := json.unmarshal(data, &deck)
	if json_err != nil {
		log_red(json_err, "when unmarshalling deck")
		return nil
	}
	return deck
}

deck_save_json :: proc(deck: Deck, path: string) {
	data, json_err := json.marshal(deck)
	if json_err != nil {
		log_red(json_err, "when marshalling deck")
		return
	}
	err := os.write_entire_file_or_err(path, data)
	if err != nil {
		log_red(err, "when writing", path)
	}
}
