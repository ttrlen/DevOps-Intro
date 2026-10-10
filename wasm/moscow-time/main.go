package main

import (
	"fmt"
	"net/http"
	"time"

	spinhttp "github.com/spinframework/spin-go-sdk/v2/http"
)

func init() {
	spinhttp.Handle(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/json")

		if r.Method != http.MethodGet {
			w.WriteHeader(http.StatusMethodNotAllowed)
			fmt.Fprintln(w, `{"error":"method not allowed"}`)
			return
		}

		moscow := time.FixedZone("MSK", 3*60*60)
		now := time.Now().In(moscow)
		fmt.Fprintf(
			w,
			`{"unix":%d,"iso":%q,"hour_minute":%q}`+"\n",
			now.Unix(),
			now.Format(time.RFC3339),
			now.Format("15:04"),
		)
	})
}
