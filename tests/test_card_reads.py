"""02: reading a Cryft card's public status (with stand-ins for the live contracts)."""
ENROLLED, RETIRED = 3, 4


def world(chain, deploy):
    cards, authority = deploy("MockCryftCards"), deploy("MockCardAuthority")
    reader = deploy("CardStatusReader", cards.address, authority.address)
    return cards, authority, reader


def test_addresses_are_checked_once(chain, deploy, reverts):
    cards = deploy("MockCryftCards")
    reverts(lambda: deploy("CardStatusReader", chain.eth.accounts[1], cards.address), "InvalidConfiguration()")
    reverts(lambda: deploy("CardStatusReader", cards.address, cards.address), "InvalidConfiguration()")


def test_an_opened_card_is_live_and_names_its_account(chain, deploy):
    cards, authority, reader = world(chain, deploy)
    maker, account = chain.eth.accounts[1], chain.eth.accounts[2]
    cards.functions.set(7, True, False, False, False, maker).transact()
    authority.functions.set(7, ENROLLED, account).transact()
    status = reader.functions.statusOf(7).call()
    assert status == (True, False, False, False, ENROLLED, maker, account)
    assert reader.functions.isLiveOpenedCard(7).call()
    assert reader.functions.requireLiveOpenedCard(7).call() == account
    assert reader.functions.metadataOf(7).call() == "ipfs://cards/7.json"


def test_not_live_cards_are_refused_without_reverting_reads(chain, deploy, reverts):
    cards, authority, reader = world(chain, deploy)
    cards.functions.set(8, True, True, False, False, chain.eth.accounts[1]).transact()     # burned
    authority.functions.set(8, RETIRED, chain.eth.accounts[2]).transact()
    authority.functions.set(9, 200, chain.eth.accounts[2]).transact()                     # an unknown state
    assert not reader.functions.isLiveOpenedCard(8).call()
    assert reader.functions.metadataOf(8).call() == ""                                    # never the revert of tokenURI
    assert reader.functions.statusOf(9).call()[4] == 0                                    # unknown → "no card"
    reverts(lambda: reader.functions.requireLiveOpenedCard(8).call(), "NotALiveCard(uint256)")


def test_batches_are_bounded(chain, deploy, reverts):
    *_, reader = world(chain, deploy)
    assert len(reader.functions.statusOfBatch(list(range(1, 51))).call()) == 50
    reverts(lambda: reader.functions.statusOfBatch(list(range(1, 52))).call(), "BatchTooLarge()")
