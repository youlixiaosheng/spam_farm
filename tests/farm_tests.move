#[test_only]
module farm::farm_tests {
    use farm::farm::{Self, AdminCap, FarmGame, Director};
    use sui::coin::{Self, Coin};

    #[test_only]
    use sui::test_scenario;
    #[test_only]
    use sui::test_utils::assert_eq;


    #[test]
    fun test_farm() {
        let admin = @0x1;
        let little_red = @0xa;
        let little_green = @0xb;
        let little_black = @0xc;
        let little_blue = @0xd;

        let mut scenario_val = test_scenario::begin(admin);
        let mut scenario = &mut scenario_val;

        // ====================
        //  init
        // ====================
        {
            farm::test_init(test_scenario::ctx(scenario));
        };


        // ====================
        //  little_red planting
        // ====================
        test_scenario::next_tx(scenario, little_red);
        {
            let mut director = test_scenario::take_shared<Director>(scenario);

            farm::planting(
                &mut director,
                &mut coin::mint_for_testing<0x30a644c3485ee9b604f52165668895092191fcaf5489a846afa7fc11cdb9b24a::spam::SPAM>(1_000_000_000, test_scenario::ctx(scenario)),
                test_scenario::ctx(scenario)
            );
            assert_eq(farm::get_epoch_games(&mut director).size(), 1);
            test_scenario::return_shared(director);
        };

        // ====================
        //  little_green planting
        // ====================
        test_scenario::next_tx(scenario, little_green);
        {
            let mut director = test_scenario::take_shared<Director>(scenario);

            farm::planting(
                &mut director,
                &mut coin::mint_for_testing<0x30a644c3485ee9b604f52165668895092191fcaf5489a846afa7fc11cdb9b24a::spam::SPAM>(1_000_000_000, test_scenario::ctx(scenario)),
                test_scenario::ctx(scenario)
            );
            assert_eq(farm::get_epoch_games(&mut director).size(), 2);
            test_scenario::return_shared(director);
        };

        // ====================
        //  little_black planting
        // ====================
        test_scenario::next_tx(scenario, little_black);
        {
            let mut director = test_scenario::take_shared<Director>(scenario);

            farm::planting(
                &mut director,
                &mut coin::mint_for_testing<0x30a644c3485ee9b604f52165668895092191fcaf5489a846afa7fc11cdb9b24a::spam::SPAM>(2_000_000_000, test_scenario::ctx(scenario)),
                test_scenario::ctx(scenario)
            );
            assert_eq(farm::get_epoch_games(&mut director).size(), 3);
            test_scenario::return_shared(director);
        };

        // ====================
        //  little_blue planting
        // ====================
        test_scenario::next_tx(scenario, little_blue);
        {
            let mut director = test_scenario::take_shared<Director>(scenario);

            farm::planting(
                &mut director,
                &mut coin::mint_for_testing<0x30a644c3485ee9b604f52165668895092191fcaf5489a846afa7fc11cdb9b24a::spam::SPAM>(3_000_000_000, test_scenario::ctx(scenario)),
                test_scenario::ctx(scenario)
            );
            assert_eq(farm::get_epoch_games(&mut director).size(), 4);
            test_scenario::return_shared(director);
        };

        test_scenario::end(scenario_val);


    }

}
