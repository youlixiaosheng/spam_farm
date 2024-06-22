# Farm Game

Farm Game is a decentralized farming simulation game implemented in Move for the Sui blockchain. Players can plant crops, harvest them, and even steal crops from other players. The game supports various special events and allows for interaction among players within a shared game state.

## Table of Contents
- [Getting Started](#getting-started)
- [Game Mechanics](#game-mechanics)
- [Special Events](#special-events)
- [Smart Contract Functions](#smart-contract-functions)
- [Error Codes](#error-codes)

## Getting Started

To get started with the Farm Game, you need to have a Sui development environment set up. Follow the instructions below to set up the project:

1. **Clone the repository:**
    ```bash
    git clone https://github.com/yourusername/farm-game.git
    cd farm-game
    ```

2. **Build the project:**
    ```bash
    sui move build
    ```

3. **Run the tests:**
    ```bash
    sui move test
    ```

## Game Mechanics

The Farm Game consists of several key mechanics:

- **Planting:** Players invest in planting crops, which will mature in the next epoch.
- **Harvesting:** Players can harvest their crops in the epoch following their planting. The rewards are proportional to their investment and special events.
- **Stealing:** Players have the option to steal crops from other players. Success rates and potential penalties are influenced by special events.

## Special Events

Special events add variability to the game, providing bonuses or penalties to players:

1. **Double Reward:** Players receive double points for their crops.
2. **Double Anti-Steal Rate:** Increases the player's resistance to being stolen from.
3. **Double Steal Success Rate:** Increases the success rate of stealing from other players.
4. **Steal Fail:** Guarantees that any steal attempt against the player will fail.

## Smart Contract Functions

### Initialization
```move
fun init(otw: FARM, ctx: &mut TxContext)
```
Initializes the game by setting up the director and admin capabilities.

### Planting
```move
public entry fun planting(
    director: &mut Director,
    investment: &mut Coin<0x30a644c3485ee9b604f52165668895092191fcaf5489a846afa7fc11cdb9b24a::spam::SPAM>,
    ctx: &mut TxContext)
```
Allows players to invest in planting crops for the current epoch.

### Stealing
```move
public entry fun steal(director: &mut Director, rnd: &Random, ctx: &mut TxContext)
```
Allows players to attempt stealing crops from other players.

### Harvesting
```move
public entry fun harvest(director: &mut Director, ctx: &mut TxContext)
```
Allows players to harvest their crops from the previous epoch.


### Pause
```move
public entry fun pause(_: &AdminCap, director: &mut Director)
```
Pauses the game.


### Resume
```move
public entry fun resume(_: &AdminCap, director: &mut Director)

```
Resumes the game.


### Error Codes
- E_INVALID_AMOUNT: The investment amount is invalid.
- E_PAUSED: The game is currently paused.
- E_GAME_DOES_NOT_EXIST: The game for the specified epoch does not exist.
- E_STOLEN: The player has already stolen in the current epoch.
- E_NOT_EXISTED_AVAILABLE_FARMER: No available farmers to steal from.
- E_NOT_INVOLVED_IN_PLANTING: The player is not involved in planting.
- E_REPEATED_HARVEST: The crop has already been harvested.




1. sui client publish --gas-budget 600600600 --skip-dependency-verification
2. 得到  PackageID: 0x940eba4a918db5ba73c3a56560cf657b5ac7d38fc552c2bc553f9f8043e550c9
3. 得到 AdminCap 0x3b418e0b2e0e6c269afedb743c7468e4288c0105b414e89b34c729a00b6892b4
4. 得到 Director  0xb654a2d8bc5503fee4d4d97ae6a4e9ff8c6557b68bc0de54f46075a937febcc3

sui client call --package 0x940eba4a918db5ba73c3a56560cf657b5ac7d38fc552c2bc553f9f8043e550c9 --module farm --function get_or_create_epoch_game --args 0xb654a2d8bc5503fee4d4d97ae6a4e9ff8c6557b68bc0de54f46075a937febcc3 --gas-budget 50000000
