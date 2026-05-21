// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/MSUTCTOCertificate.sol";

contract Deploy is Script {
    function run() external returns (address) {
        vm.startBroadcast();

        MSUTCTOCertificate cert = new MSUTCTOCertificate();

        vm.stopBroadcast();

        return address(cert);
    }
}