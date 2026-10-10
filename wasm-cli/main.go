package main

import (
	"fmt"
	"os"
	"time"
)

func main() {
	if os.Getenv("REQUEST_METHOD") != "GET" || os.Getenv("PATH_INFO") != "/time" {
		fmt.Println(`{"error":"only GET /time is supported"}`)
		return
	}

	moscow := time.FixedZone("MSK", 3*60*60)
	now := time.Now().In(moscow)
	fmt.Printf(
		`{"unix":%d,"iso":%q,"hour_minute":%q}`+"\n",
		now.Unix(),
		now.Format(time.RFC3339),
		now.Format("15:04"),
	)
}
