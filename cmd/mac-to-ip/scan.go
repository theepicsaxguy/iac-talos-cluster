// Copyright (c) 2023, Roel Schut. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

package main

import (
	"bufio"
	"bytes"
	"os/exec"
	"strings"
	"time"

	"github.com/go-pogo/errors"
)

const (
	foundHost  = "Nmap scan report for "
	foundMac   = "MAC Address: "
	maxRetries = 5
	retryDelay = 10 * time.Second
)

func scanSubnet(cidr []string, targetMacs []string) (map[string]string, error) {
	var result map[string]string
	var err error

	for i := 0; i < maxRetries; i++ {
		result, err = doScan(cidr, targetMacs)
		if err != nil {
			return nil, errors.WithStack(err)
		}

		// Check if we found all target MACs
		allFound := true
		for _, mac := range targetMacs {
			if _, found := result[strings.ToLower(mac)]; !found {
				allFound = false
				break
			}
		}

		if allFound {
			return result, nil
		}

		// Not all MACs found, wait and retry
		time.Sleep(retryDelay)
	}

	return result, nil
}

func doScan(cidr []string, targetMacs []string) (map[string]string, error) {
	// Use -T4 for faster timing, --min-rate to ensure minimum packet rate,
	// --max-retries for reliability with slow responses
	args := []string{"-sn", "-T4", "--min-rate=300", "--max-retries=3"}
	args = append(args, cidr...)

	b, err := exec.Command("nmap", args...).Output()
	if err != nil {
		return nil, errors.WithStack(err)
	}

	scan := bufio.NewScanner(bytes.NewBuffer(b))
	scan.Split(bufio.ScanLines)

	hasTargets := len(targetMacs) > 0
	result := make(map[string]string)

	var currentIP string
	for scan.Scan() {
		line := scan.Text()
		if strings.Contains(line, foundHost) {
			parts := strings.Split(line, " ")
			currentIP = strings.Trim(parts[len(parts)-1], "()")
			// Handle hostnames by taking the IP in parentheses if present
			if strings.Contains(currentIP, "(") {
				currentIP = strings.Trim(strings.Split(currentIP, "(")[1], ")")
			}
		} else if strings.Contains(line, foundMac) {
			parts := strings.Split(line, " ")
			mac := strings.ToLower(parts[2])
			if hasTargets && !contains(targetMacs, mac) {
				continue
			}
			result[mac] = currentIP
		}
	}

	return result, nil
}

func contains(list []string, str string) bool {
	for _, test := range list {
		if strings.EqualFold(test, str) {
			return true
		}
	}
	return false
}
