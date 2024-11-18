package main

import (
	"fmt"
	"net/http"
)

func handler(w http.ResponseWriter, r *http.Request) {
	fmt.Fprintf(w, "Hello, people!")
}

func main() {
	http.HandleFunc("/", handler)
	http.ListenAndServe(":9999", nil)
}
