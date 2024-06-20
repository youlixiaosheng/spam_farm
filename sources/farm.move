module farm::farm {

    use std::ascii::{String, string};
    use sui::coin::{Self, Coin};
    use sui::balance::{Self, Balance};
    use sui::event;
    use sui::package;
    use sui::random::{Random, new_generator};
    use sui::table;
    use sui::table::Table;
    use sui::vec_map;
    use sui::vec_map::VecMap;

    // ===> ErrorCodes <===
    const E_INVALID_AMOUNT: u64 = 1;
    const E_PAUSED: u64 = 2;
    const E_GAME_DOES_NOT_EXIST: u64 = 3;
    const E_STOLEN: u64 = 4;
    const E_NOT_EXISTED_AVAILABLE_FARMER: u64 = 5;
    const E_NOT_INVOLVED_IN_PLANTING: u64 = 6;
    const E_REPEATED_HARVEST: u64 = 7;

    // ===> special_event Constants <===
    // 1. No attribute
    // 2. Double points reward
    // 3. Double anti-steal rate
    // 4. Double steal success rate
    // 5. Steal failure rate 100%
    // const NO_SPECIAL_EVENT: u64 = 1;
    const DOUBLE_REWARD: u64 = 2;
    const DOUBLE_ANTI_STEAL: u64 = 3;
    const DOUBLE_STEAL_SUCCESS: u64 = 4;
    const STEAL_FAIL: u64 = 5;

    // ===> Events <===
    public struct EventSteal has copy, drop {
        sender: address,
        target: address,
        epoch: u64,
        success: bool,
        reward: u64,
    }

    public struct EventHarvest has copy, drop {
        sender: address,
        epoch: u64,
        reward: u64
    }

    public struct EventPlanting has copy, drop {
        sender: address,
        epoch: u64,
        investment_value: u64,
        balance: u64
    }

    // ===> Structures <===
    public struct FARM has drop {}

    public struct AdminCap has key {
        id: UID,
    }

    /// Singleton shared object for recording the game state of each epoch.
    public struct Director has key, store {
        id: UID,
        paused: bool, // Main switch
        epoch_games: Table<u64, FarmGame>, // Table keyed by epoch
    }

    public struct Crop has store, copy {
        name: String, // Name
        epoch: u64, // Planting epoch
        mature_epoch: u64, // Matures in the next epoch
        investment: u64,
        harvestable: bool, // Harvestable or not
        harvested: bool, // Harvested or not
        stolen: bool, // Stolen or not
        token_reward: u64, // Points reward after harvest, distributed proportionally in the next epoch's balance pool
    }

    public struct FarmUser has store {
        address: address,
        steal: bool,
        investment: u64,
        rewards: u64, // Rewards generated when others are caught stealing
        special_event: u64,
        crop: Crop,
    }

    public struct FarmGame has store {
        epoch: u64,
        balance_pool: u64,
        investments: Balance<0x30a644c3485ee9b604f52165668895092191fcaf5489a846afa7fc11cdb9b24a::spam::SPAM>,
        farm_users: VecMap<address, FarmUser>,
    }

    // ===> Functions <===
    fun init(otw: FARM, ctx: &mut TxContext) {
        package::claim_and_keep(otw, ctx);

        transfer::share_object(
            Director {
                id: object::new(ctx),
                paused: false,
                epoch_games: table::new(ctx),
            }
        );

        transfer::transfer(AdminCap{
            id: object::new(ctx)
        }, tx_context::sender(ctx));
    }

    fun get_or_create_epoch_game(
        director: &mut Director,
        ctx: &mut TxContext,
    ): &mut FarmGame {
        let epoch = tx_context::epoch(ctx);
        if (!director.epoch_games.contains(epoch)) {
            let balance_pool = 0;
            let epoch_game = FarmGame {
                epoch,
                balance_pool,
                investments: coin::into_balance(coin::zero<0x30a644c3485ee9b604f52165668895092191fcaf5489a846afa7fc11cdb9b24a::spam::SPAM>(ctx)),
                farm_users: vec_map::empty<address, FarmUser>(),
            };
            director.epoch_games.add(epoch, epoch_game);
        };
        return director.epoch_games.borrow_mut(epoch)
    }

    fun create_crop(epoch: u64, investment_value: u64, special_event: u64): Crop {
        let name = string(b"Spam");
        let mature_epoch = epoch + 1;
        let investment = 0;
        let harvestable = false;
        let harvested = false;
        let stolen = false;
        let mut token_reward = investment_value;
        if (special_event == DOUBLE_REWARD) {
            token_reward = token_reward * 2;
        };
        let crop = Crop {
            name,
            epoch,
            mature_epoch,
            investment,
            harvestable,
            harvested,
            stolen,
            token_reward,
        };
        crop
    }

    fun create_farmer(epoch: u64, address: address, investment_value: u64): FarmUser {
        let investment = investment_value;
        let rewards = 0;
        let special_event = 0; // Generate a random event
        let crop = create_crop(epoch, investment_value, special_event);

        let steal = false;
        FarmUser {
            address,
            steal,
            investment,
            rewards,
            special_event,
            crop,
        }
    }

    fun get_game_by_epoch(director: &mut Director, epoch: u64): &mut FarmGame {
        assert!(director.epoch_games.contains(epoch), E_GAME_DOES_NOT_EXIST);
        director.epoch_games.borrow_mut(epoch)
    }

    fun get_farmer_by_epoch(director: &mut Director, epoch: u64, sender: address): &mut FarmUser {
        let epoch_game = get_game_by_epoch(director, epoch);
        assert!(vec_map::contains(&epoch_game.farm_users, &sender), E_NOT_INVOLVED_IN_PLANTING);
        epoch_game.farm_users.get_mut(&sender)
    }

    // Planting
    public entry fun planting(
        director: &mut Director,
        investment: &mut Coin<0x30a644c3485ee9b604f52165668895092191fcaf5489a846afa7fc11cdb9b24a::spam::SPAM>,
        ctx: &mut TxContext)
    {
        let sender = tx_context::sender(ctx);
        let epoch = tx_context::epoch(ctx);
        let investment_value = coin::value(investment);
        let paid = coin::split(investment, investment_value, ctx);
        // Minimum of 1 spam coin
        assert!(investment_value >= 1_000_000_000, E_INVALID_AMOUNT);
        // Check if the main switch is on
        assert!(director.paused == false, E_PAUSED);
        // Get or create the current epoch's game
        let farm_game = get_or_create_epoch_game(director, ctx);
        let farm_users = &mut farm_game.farm_users;
        // Check if exists
        assert!(vec_map::contains(farm_users, &sender) == false, E_NOT_INVOLVED_IN_PLANTING);
        let farm_user = create_farmer(epoch, sender, investment_value);

        // Add user
        farm_users.insert(sender, farm_user);
        farm_game.investments.join(coin::into_balance(paid));
        event::emit(EventPlanting{
            epoch,
            sender,
            investment_value,
            balance: investment_value
        });
    }

    // Steal
    public entry fun steal(director: &mut Director, rnd: &Random, ctx: &mut TxContext) {
        // Check if the main switch is on
        assert!(director.paused == false, E_PAUSED);
        let epoch = tx_context::epoch(ctx);
        let sender = tx_context::sender(ctx);

        // Get the current epoch's game
        assert!(director.epoch_games.contains(epoch), E_GAME_DOES_NOT_EXIST);
        let farm_game = director.epoch_games.borrow_mut(epoch);
        let size = farm_game.farm_users.size();

        assert!(vec_map::contains(&farm_game.farm_users, &sender), E_NOT_INVOLVED_IN_PLANTING);
        let farmer = farm_game.farm_users.get_mut(&sender);
        // Check if already stolen
        assert!(farmer.steal == false, E_STOLEN);

        let mut steal_flag = false;
        // Randomly get an unstolen crop from the game
        // Loop
        let mut i: u64 = 0;
        while (i < size) {
            let (address, farm_user) = farm_game.farm_users.get_entry_by_idx_mut(i);

            // Filter out self
            if (address == sender) {
                i = i + 1;
                continue
            };
            if (farm_user.crop.stolen == false) {
                let mut success_rate = 40; // Default success rate is 40%
                // Calculate own special event
                if (farm_user.special_event == DOUBLE_STEAL_SUCCESS) {
                    success_rate = success_rate * 2;
                };

                // Calculate opponent's special event
                if (farm_user.special_event == DOUBLE_ANTI_STEAL) {
                    success_rate = success_rate / 2;
                };
                if (farm_user.special_event == STEAL_FAIL) {
                    success_rate = 0;
                };
                let mut be_found = false;
                if (success_rate == 0) {
                    be_found = true;
                } else {
                    // Get a random value
                    let mut gen = new_generator(rnd, ctx);
                    let random_num = gen.generate_u32_in_range(1, 100);
                    if (random_num > success_rate) {
                        be_found = true;
                    };
                };

                let my_rewards = farmer.rewards; // Own rewards
                let other_rewards = farm_user.rewards; // Opponent's rewards
                // Each divided by half, take the minimum
                let final_reward = if (my_rewards / 2 < other_rewards / 2) {
                    my_rewards / 2
                } else {
                    other_rewards / 2
                };
                if (be_found) {
                    // Caught
                    // Reset rewards
                    farm_user.rewards = farm_user.rewards + final_reward;
                    farmer.rewards = farmer.rewards - final_reward;
                } else {
                    // Not caught
                    // Successful steal
                    farm_user.rewards = farm_user.rewards - final_reward;
                    farmer.rewards = farmer.rewards + final_reward;
                };
                steal_flag = true;
                farmer.steal = true;
                farm_user.crop.stolen = true;
                // Steal event
                event::emit(EventSteal {
                    sender,
                    target: *address,
                    epoch,
                    success: !be_found,
                    reward: final_reward,
                });
                break
            };
            i = i + 1;
        };
        assert!(steal_flag == true, E_NOT_EXISTED_AVAILABLE_FARMER);
    }

    // Harvest crops from the previous epoch
    public entry fun harvest(director: &mut Director, ctx: &mut TxContext) {
        // Check if participated in the previous epoch
        let pre_epoch = tx_context::epoch(ctx) - 1;
        let sender = tx_context::sender(ctx);
        let farmer = get_farmer_by_epoch(director, pre_epoch, sender);
        // Check if already harvested
        assert!(farmer.crop.harvested == false, E_REPEATED_HARVEST);

        let rewards = farmer.rewards;
        let crop_token_reward = farmer.crop.token_reward;
        // Update rewards
        farmer.crop.harvested = true;

        // Get the previous epoch's game
        let farm_game = get_game_by_epoch(director, pre_epoch);
        let balance_pool = farm_game.balance_pool;

        // Harvest reward
        let final_reward = rewards + crop_token_reward;
        // Distribute reward
        // Split the coin
        let investments_balance = balance::split(&mut farm_game.investments, final_reward);
        let coin_reward = coin::from_balance(investments_balance, ctx);
        // Transfer
        transfer::public_transfer(coin_reward, sender);

        // Update balance pool
        farm_game.balance_pool = balance_pool - final_reward;
        // Harvest event
        event::emit(EventHarvest{
            sender,
            epoch: pre_epoch,
            reward: final_reward,
        });
    }

    // Pause
    public entry fun pause(_: &AdminCap, director: &mut Director) {
        director.paused = true;
    }

    // Resume
    public entry fun resume(_: &AdminCap, director: &mut Director) {
        director.paused = false;
    }

    #[test_only]
    public fun get_epoch_games(director: &mut Director): &Table<u64, FarmGame> {
        &director.epoch_games
    }

    #[test_only]
    public fun test_init(ctx: &mut TxContext) {
        init(FARM{}, ctx)
    }

}
