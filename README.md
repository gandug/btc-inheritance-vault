 BTC Inheritance Vault - Clarity Smart Contract

The **BTC Inheritance Vault** is a Clarity smart contract designed for the [Stacks blockchain](https://stacks.co), enabling secure, decentralized inheritance of BTC-linked assets through a time-locked vault mechanism.

---

 Features

-  **Designate Heirs:** Owners can assign a trusted heir to inherit their BTC assets.
-  **Inactivity Timer:** Inheritance is unlocked after a configurable period of owner inactivity.
-  **Heartbeat Function:** Owners can reset the timer by signaling continued activity.
-  **Secure Claims:** Only authorized heirs can claim assets post-inactivity.
-  **Transparent Status:** Vault state and timings are publicly readable.

---

 Smart Contract Functions

 Public Functions

| Function                  | Description                                         |
|---------------------------|-----------------------------------------------------|
| `register-vault`          | Register a vault with an heir and timeout period    |
| `heartbeat`               | Reset the inactivity timer to prevent inheritance  |
| `claim-inheritance`       | Allow heir to claim assets after timeout            |

 Read-Only Functions

| Function                  | Description                          |
|---------------------------|--------------------------------------|
| `get-vault-info`          | View the vault details for an owner |

---

 Example Usage

```clarity
;; Register vault with heir and inactivity period of 100 blocks
(register-vault 'SP2...ABC' u100)

;; Owner sends a heartbeat to reset the timer
(heartbeat)

;; Heir claims inheritance after inactivity timeout
(claim-inheritance 'SP2...OWNER)
