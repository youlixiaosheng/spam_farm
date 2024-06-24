#[test_only]
module farm::farm_tests {
    use farm::farm::{Self, AdminCap, FarmGame, Director};
    use sui::coin::{Self, Coin};
    use sui::sui::{SUI};
    use sui::test_scenario::{Self as ts, next_tx, Scenario};
    use sui::test_utils::assert_eq;
    use sui::transfer;


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
        // ts::next_tx(scenario, little_green);
        // {
        //     let mut director = ts::take_shared<Director>(scenario);

        //     farm::planting(
        //         &mut director,
        //         &mut coin::mint_for_testing<0x30a644c3485ee9b604f52165668895092191fcaf5489a846afa7fc11cdb9b24a::spam::SPAM>(1_000_000_000, ts::ctx(scenario)),
        //         ts::ctx(scenario)
        //     );
        //     assert_eq(farm::get_epoch_games(&mut director).size(), 2);
        //     ts::return_shared(director);
        // };

        // // ====================
        // //  little_black planting
        // // ====================
        // ts::next_tx(scenario, little_black);
        // {
        //     let mut director = ts::take_shared<Director>(scenario);

        //     farm::planting(
        //         &mut director,
        //         &mut coin::mint_for_testing<0x30a644c3485ee9b604f52165668895092191fcaf5489a846afa7fc11cdb9b24a::spam::SPAM>(2_000_000_000, ts::ctx(scenario)),
        //         ts::ctx(scenario)
        //     );
        //     assert_eq(farm::get_epoch_games(&mut director).size(), 3);
        //     ts::return_shared(director);
        // };

        // // ====================
        // //  little_blue planting
        // // ====================
        // ts::next_tx(scenario, little_blue);
        // {
        //     let mut director = ts::take_shared<Director>(scenario);

        //     farm::planting(
        //         &mut director,
        //         &mut coin::mint_for_testing<0x30a644c3485ee9b604f52165668895092191fcaf5489a846afa7fc11cdb9b24a::spam::SPAM>(3_000_000_000, ts::ctx(scenario)),
        //         ts::ctx(scenario)
        //     );
        //     assert_eq(farm::get_epoch_games(&mut director).size(), 4);
        //     ts::return_shared(director);
        // };

        ts::end(scenario_val);


    }

}
