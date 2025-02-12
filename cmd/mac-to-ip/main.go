// Copyright (c) 2023, Roel Schut. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

package main

import (
	"encoding/json"
	"flag"
	"fmt"
	"log"
	"strings"
)

func main() {
	subnet := flag.String("subnet", "", "Subnet to scan in CIDR notation")
	flag.Parse()

	if *subnet == "" {
		log.Fatal("subnet parameter is required")
	}

	macs := flag.Args()
	if len(macs) == 0 {
		log.Fatal("at least one MAC address must be provided")
	}

	// Get MAC to IP mapping
	macToIP, err := scanSubnet(strings.Split(*subnet, ","), macs)
	if err != nil {
		log.Fatal(err)
	}

	// Build result map for Terraform
	result := make(map[string]string)
	for i, mac := range macs {
		mac = strings.ToLower(mac)
		if ip, ok := macToIP[mac]; ok {
			result[fmt.Sprintf("ip%d", i)] = ip
		} else {
			log.Printf("Warning: No IP found for MAC %s", mac)
			result[fmt.Sprintf("ip%d", i)] = ""
		}
	}

	// Output JSON for Terraform
	json, err := json.Marshal(result)
	if err != nil {
		log.Fatal(err)
	}
	fmt.Print(string(json))
}
