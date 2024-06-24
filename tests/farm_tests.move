#[test_only]
module farm::farm_tests {
    use farm::farm::{Self, AdminCap, FarmGame, Director};
    use sui::coin::{Self, Coin};
    use sui::sui::{SUI};
    use sui::test_scenario::{Self as ts, next_tx, Scenario};
    use sui::test_utils::assert_eq;
    use sui::transfer;
    use sui::random::{Self, Random};

    #[test]
    fun test_farm() {
        let admin = @0x1;
        let little_red = @0xa;
        let little_green = @0xb;
        let little_black = @0xc;
        let little_blue = @0xd;

        let mut scenario_val = ts::begin(admin);
        let mut scenario = &mut scenario_val;

        // ====================
        //  init
        // ====================
        {
            farm::test_init(ts::ctx(scenario));
        };


        // ====================
        //  little_red planting
        // ====================
        ts::next_tx(scenario, little_red);
        {
            let mut director = ts::take_shared<Director>(scenario);
            let coin_ = coin::mint_for_testing<SUI>(1000_000_000_000, ts::ctx(scenario));

            let advanced_coin = farm::planting(
                &mut director,
                coin_,
                ts::ctx(scenario)
            );
            assert_eq(farm::get_epoch_games(&director), 1);
            ts::return_shared(director);
            transfer::public_transfer(advanced_coin, little_red);
        };

        // ====================
        //  little_green planting
        // ====================
        ts::next_tx(scenario, little_green);
        {
            let mut director = ts::take_shared<Director>(scenario);
            let coin_ = coin::mint_for_testing<SUI>(1000_000_000_000, ts::ctx(scenario));

            let advanced_coin = farm::planting(
                &mut director,
                coin_,
                ts::ctx(scenario)
            );
            assert_eq(farm::get_epoch_games(&director), 1);
            ts::return_shared(director);
            transfer::public_transfer(advanced_coin, little_green);
        };

        // // ====================
        // //  little_black planting
        // // ====================
        ts::next_tx(scenario, little_black);
        {
            let mut director = ts::take_shared<Director>(scenario);
            let coin_ = coin::mint_for_testing<SUI>(1000_000_000_000, ts::ctx(scenario));

            let advanced_coin = farm::planting(
                &mut director,
                coin_,
                ts::ctx(scenario)
            );
            assert_eq(farm::get_epoch_games(&director), 1);
            ts::return_shared(director);
            transfer::public_transfer(advanced_coin, little_black);
        };

        // // ====================
        // //  little_blue planting
        // // ====================
        ts::next_tx(scenario, little_blue);
        {
            let mut director = ts::take_shared<Director>(scenario);
            let coin_ = coin::mint_for_testing<SUI>(1000_000_000_000, ts::ctx(scenario));

            let advanced_coin = farm::planting(
                &mut director,
                coin_,
                ts::ctx(scenario)
            );
            assert_eq(farm::get_epoch_games(&director), 1);
            ts::return_shared(director);
            transfer::public_transfer(advanced_coin, little_blue);
        };

        ts::next_tx(scenario, little_red);
        {
            let mut director = ts::take_shared<Director>(scenario);
            random::create_for_testing(ts::ctx(scenario));
            let random_ = ts::take_shared<Random>(scenario);

            farm::steal(
                &mut director,
                &random_,
                ts::ctx(scenario)
            );
            assert_eq(farm::get_epoch_games(&director), 1);
            ts::return_shared(director);
            ts::return_shared(random_);
        };

        ts::end(scenario_val);
    }
}
