module farm::farm {

    use std::ascii::{String, string};
    use sui::sui::SUI;
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
    // 1. 无属性
    // 2. 积分奖励 * 2
    // 3. 防偷率 * 2
    // 4. 偷取成功率 * 2
    // 5. 被偷取失败率 100%
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

    /// 单例共享对象，用于记录每个时代的游戏状态。
    public struct Director has key, store {
        id: UID,
        paused: bool, // 总开关
        epoch_games: Table<u64, FarmGame>, // 键为时代的表
    }

    public struct Crop has store , copy{
        name: String, // 名称
        epoch: u64, // 种植的纪元
        mature_epoch: u64, // 下个纪元成熟
        investment: u64,
        harvestable: bool, //是否可收获
        harvested: bool, //是否已收获
        stolen: bool, //是否被偷取
        token_reward: u64, // 积分回报 收割后的奖励 下个纪元按照比例分配 balance_pool
    }

    public struct FarmUser has store {
        address: address,
        steal: bool,
        investment: u64,
        rewards: u64, // 当其他人进行偷取时被发现, 产生的奖励
        special_event: u64,
        crop: Crop,
    }

    public struct FarmGame has store {
        epoch: u64,
        balance_pool: u64,
        investments: Balance<SUI>,
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
                investments: coin::into_balance(coin::zero<SUI>(ctx)),
                farm_users: vec_map::empty<address, FarmUser>(),
            };
            director.epoch_games.add(epoch, epoch_game);
        };
        return director.epoch_games.borrow_mut(epoch)
    }

    fun create_crop(epoch: u64, investment_value: u64, special_event:u64) : Crop {
        let name = string(b"Sui");
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

    fun create_farmer(epoch: u64, address: address, investment_value: u64) : FarmUser {
        let investment = investment_value;
        let rewards = 0;
        let special_event = 0; // 进行随机生成一个
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

    fun get_game_by_epoch(director: &mut Director, epoch: u64) : &mut FarmGame {
        assert!(director.epoch_games.contains(epoch), E_GAME_DOES_NOT_EXIST);
        director.epoch_games.borrow_mut(epoch)
    }

    fun get_farmer_by_epoch(director: &mut Director, epoch: u64, sender: address) : &mut FarmUser {
        let epoch_game = get_game_by_epoch(director, epoch);
        assert!(vec_map::contains(&epoch_game.farm_users, &sender), E_NOT_INVOLVED_IN_PLANTING);
        epoch_game.farm_users.get_mut(&sender)
    }

    // 进行种植
    public entry fun planting(
        director: &mut Director,
        investment: &mut Coin<SUI>,
        ctx: &mut TxContext)
    {
        let sender = tx_context::sender(ctx);
        let epoch = tx_context::epoch(ctx);
        let investment_value = coin::value(investment);
        let paid = coin::split(investment, investment_value, ctx);
        // 最低为1个SUI
        assert!(investment_value >= 1_000_000_000, E_INVALID_AMOUNT);
        // 校验总开关是否打开
        assert!(director.paused == false, E_PAUSED);
        // 获取或创建当前时代的游戏
        let farm_game = get_or_create_epoch_game(director, ctx);
        let farm_users = &mut farm_game.farm_users;
        // 判断是否存在
        assert!(vec_map::contains(farm_users, &sender) == false, E_NOT_INVOLVED_IN_PLANTING);
        let farm_user = create_farmer(epoch, sender, investment_value);

        // 添加用户
        farm_users.insert(sender, farm_user);
        farm_game.investments.join(coin::into_balance(paid));
        event::emit(EventPlanting{
            epoch,
            sender,
            investment_value,
            balance: investment_value
        });
    }

    // 进行偷取
    public entry fun steal(director: &mut Director, rnd: &Random, ctx: &mut TxContext) {
        // 校验总开关是否打开
        assert!(director.paused == false, E_PAUSED);
        let epoch = tx_context::epoch(ctx);
        let sender = tx_context::sender(ctx);

        // 获取当前纪元的游戏
        assert!(director.epoch_games.contains(epoch), E_GAME_DOES_NOT_EXIST);
        let farm_game = director.epoch_games.borrow_mut(epoch);
        let size = farm_game.farm_users.size();

        assert!(vec_map::contains(&farm_game.farm_users, &sender), E_NOT_INVOLVED_IN_PLANTING);
        let mut final_rewards = {
            let farmer = farm_game.farm_users.get(&sender);
            // 校验是否已经偷取过
            assert!(farmer.steal == false, E_STOLEN);
            farmer.rewards
        };

        let mut steal_flag = false;
        // 从游戏随机获取一个未被偷采的农作物
        // 遍历
        let mut i = 0;
        while (i < size) {
            let (address, farm_user) = farm_game.farm_users.get_entry_by_idx_mut(i);

            // 过滤掉自己
            if (*address == sender) {
                i = i+1;
                continue
            };
            if (farm_user.crop.stolen == false) {
                let mut success_rate = 40; // 默认成功率为 40%
                // 计算自己的特殊事件
                if (farm_user.special_event == DOUBLE_STEAL_SUCCESS) {
                    success_rate = success_rate * 2;
                };

                // 计算对方的特殊事件
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
                    // 获取一个随机值
                    let mut gen = new_generator(rnd, ctx);
                    let random_num = gen.generate_u32_in_range(1, 100);
                    if (random_num > success_rate) {
                        be_found = true;
                    };
                };

                let my_rewards = final_rewards; // 自己的奖励
                let other_rewards = farm_user.rewards; // 对方的奖励
                // 各除以一半 取最小值
                let final_reward = if (my_rewards / 2 < other_rewards / 2) {
                    my_rewards / 2
                } else {
                    other_rewards / 2
                };
                if (be_found) {
                    // 被发现
                    // 重置奖励
                    // let (_, farm_user) = farm_game.farm_users.get_entry_by_idx_mut(i);
                    farm_user.rewards = farm_user.rewards + final_reward;
                    final_rewards = final_rewards - final_reward;
                    farm_user.crop.stolen = true;
                    // farmer.rewards = farmer.rewards - final_reward;
                } else {
                    // 未被发现
                    // 偷取成功
                    // let (_, farm_user) = farm_game.farm_users.get_entry_by_idx_mut(i);
                    farm_user.rewards = farm_user.rewards - final_reward;
                    final_rewards = final_rewards + final_reward;
                    // farmer.rewards = farmer.rewards + final_reward;
                    farm_user.crop.stolen = true;
                };
                steal_flag = true;
                // 偷取事件
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

        let farmer = farm_game.farm_users.get_mut(&sender);
        farmer.steal = true;
        farmer.rewards = final_rewards;
        assert!(steal_flag == true, E_NOT_EXISTED_AVAILABLE_FARMER);
    }

    // 收割上一个纪元的作物
    public entry fun harvest(director: &mut Director, ctx: &mut TxContext) {
        // 判断上一个纪元是否参加过
        let pre_epoch = tx_context::epoch(ctx) - 1;
        let sender = tx_context::sender(ctx);
        let farmer = get_farmer_by_epoch(director, pre_epoch, sender);
        // 判断是否已经收割了
        assert!(farmer.crop.harvested == false, E_REPEATED_HARVEST);

        let rewards = farmer.rewards;
        let crop_token_reward = farmer.crop.token_reward;
        // 更新奖励
        farmer.crop.harvested = true;

        // 获取上一个纪元的游戏
        let farm_game = get_game_by_epoch(director, pre_epoch);
        let balance_pool = farm_game.balance_pool;

        // 收割奖励为
        let final_reward = rewards + crop_token_reward;
        // 发放奖励
        // 拆分币
        let investments_balance = balance::split(&mut farm_game.investments,final_reward);
        let coin_reward = coin::from_balance(investments_balance, ctx);
        // 进行发放
        transfer::public_transfer(coin_reward, sender);

        // 更新奖池
        farm_game.balance_pool = balance_pool - final_reward;
        // 收割事件
        event::emit(EventHarvest{
            sender,
            epoch: pre_epoch,
            reward: final_reward,
        });
    }

    // 暂停
    public entry fun pause(_: &AdminCap, director: &mut Director) {
        director.paused = true;
    }

    // 恢复
    public entry fun resume(_: &AdminCap, director: &mut Director) {
        director.paused = false;
    }

    #[test_only]
    public fun get_epoch_games(director: &mut Director): &Table<u64, FarmGame> {
        &director.epoch_games
    }

    #[test_only]
    public fun test_init(ctx: &mut TxContext) {
        init(FARM{ },ctx)
    }

}