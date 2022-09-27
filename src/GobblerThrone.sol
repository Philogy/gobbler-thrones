// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.15;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Multicall} from "@openzeppelin/contracts/utils/Multicall.sol";
import {ERC20} from "solmate/tokens/ERC20.sol";
import {IArtGobblers} from "./IArtGobblers.sol";

/// @author Philogy <https://github.com/Philogy>
/// @dev WARNING: basic af, not optimized just yet
contract GobblerThrone is ERC20, Multicall {
    struct Participant {
        address account;
        uint16 gobblerId;
        uint8 multiple;
    }
    mapping(uint256 => Participant) internal participants;

    uint256 internal constant FIRST_LEGENDARY_GOBBLER_ID = 9991;
    // 1000 shares / 1x gobbler multiple
    uint256 internal constant MULTIPLE_TO_SHARES_FACTOR = 1e21;

    uint128 internal constant AUCTION_START_PRICE = 1e18; // 1 GOO
    uint256 internal constant ONE_IN_BPS = 10000; // 5%
    uint256 internal constant BID_MIN_INCREASE_BPS = 500; // 5%
    uint256 internal constant BID_MIN_INCREASE_FACTOR_BPS =
        ONE_IN_BPS + BID_MIN_INCREASE_BPS; // x1.05
    uint256 internal constant AUCTION_GRACE_PERIOD = 30 minutes;
    uint256 internal constant AUCTION_START_DURATION = 7 days;

    // Model contract as finite state machine for the sake of simplicity and
    // security
    enum ThroneState {
        Forming,
        FormationFailed,
        Formed,
        AuctionInProgress,
        Dissolved
    }

    ThroneState internal state;
    uint16 public totalJoined;
    uint16 public totalParticipants;
    uint16 public legendaryGobblerId;

    // auction data
    uint64 public auctionEnd;
    uint128 public bestBid;
    address public topBidder;

    uint256 public immutable auctionStartsAt;
    uint256 public immutable formationFailsAt;
    IArtGobblers public immutable artGobblers;
    IERC20 public immutable goo;

    error WrongState();
    error UnacceptableGobbler();
    error SharesAlreadyIssued();
    error NotParticipant();
    error ParticipantCannotExit();
    error InsufficientGobblers();
    error BidTooLow();

    constructor(
        address _artGobblers,
        uint256 _maxFormationTime,
        uint256 _totalLifeTime
    ) ERC20("Gobbler Throne Shares", "GOTTEM", 18) {
        assert(_maxFormationTime < _totalLifeTime);
        auctionStartsAt = block.timestamp + _totalLifeTime;
        formationFailsAt = block.timestamp + _maxFormationTime;
        artGobblers = IArtGobblers(_artGobblers);
        goo = IERC20(IArtGobblers(_artGobblers).goo());
    }

    modifier onlyState(ThroneState _expectedState) {
        if (state != _expectedState) revert WrongState();
        _;
    }

    /// @dev deposit a Gobbler, adding a potential piece to the throne
    function join(uint256 _gobblerId) external onlyState(ThroneState.Forming) {
        artGobblers.transferFrom(msg.sender, address(this), _gobblerId);
        unchecked {
            uint256 emissionsMultiple = artGobblers.getGobblerEmissionMultiple(
                _gobblerId
            );
            // abuse underflow for cheaper range check
            if (
                (emissionsMultiple - 6) >= 4 ||
                _gobblerId >= FIRST_LEGENDARY_GOBBLER_ID
            ) revert UnacceptableGobbler();

            participants[totalJoined++] = Participant({
                account: msg.sender,
                gobblerId: uint16(_gobblerId),
                multiple: uint8(emissionsMultiple)
            });
        }
    }

    /// @dev attempts to mint the legendary Gobbler
    function form() external onlyState(ThroneState.Forming) {
        uint256 gobblersToBeSacrificed = artGobblers.legendaryGobblerPrice();
        if (totalJoined < gobblersToBeSacrificed) revert InsufficientGobblers();
        uint256[] memory gobblerIds = new uint256[](gobblersToBeSacrificed);
        for (uint256 i; i < gobblersToBeSacrificed; ) {
            gobblerIds[i] = participants[i].gobblerId;
            // prettier-ignore
            unchecked { i++; }
        }
        legendaryGobblerId = uint16(
            artGobblers.mintLegendaryGobbler(gobblerIds)
        );
        totalParticipants = uint16(gobblersToBeSacrificed);
        state = ThroneState.Formed;
    }

    /// @dev enter failure mode if necessary timestamp was passed
    function checkFailedFormation() external onlyState(ThroneState.Forming) {
        if (block.timestamp >= formationFailsAt)
            state = ThroneState.FormationFailed;
    }

    /// @dev retrieve Gobbler if throne formation failed
    function failExit(uint256 _participantId)
        external
        onlyState(ThroneState.FormationFailed)
    {
        address account = participants[_participantId].account;
        uint256 gobblerId = participants[_participantId].gobblerId;
        delete participants[_participantId];
        artGobblers.transferFrom(address(this), account, gobblerId);
    }

    /// @dev if legendary Gobbler was minted get shares
    function issueShares(uint256 _participantId)
        external
        onlyState(ThroneState.Formed)
    {
        if (_participantId >= totalParticipants) revert NotParticipant();
        address account = participants[_participantId].account;
        uint256 multiple = participants[_participantId].multiple;
        if (account == address(0)) revert SharesAlreadyIssued();
        delete participants[_participantId];
        _mint(account, MULTIPLE_TO_SHARES_FACTOR * multiple);
    }

    /// @dev retrieve Gobbler that couldn't be used to mint legendary
    function notParticipantExit(uint256 _participantId)
        external
        onlyState(ThroneState.Formed)
    {
        if (_participantId < totalParticipants) revert ParticipantCannotExit();
        address account = participants[_participantId].account;
        uint256 gobblerId = participants[_participantId].gobblerId;
        delete participants[_participantId];
        artGobblers.transferFrom(address(this), account, gobblerId);
    }

    /// @dev check if throne dissolution auction can begin
    function checkAuctionStart() external onlyState(ThroneState.Formed) {
        if (block.timestamp >= auctionStartsAt) {
            state = ThroneState.AuctionInProgress;
            auctionEnd = uint64(block.timestamp + AUCTION_START_DURATION);
            bestBid = AUCTION_START_PRICE;
        }
    }

    /// @dev bid in auction using GOO tokens
    function bid(uint256 _bidAmount)
        external
        onlyState(ThroneState.AuctionInProgress)
    {
        goo.transferFrom(msg.sender, address(this), _bidAmount);
        if (checkAuctionEnd()) return;
        address cachedTopBidder = topBidder;
        uint256 prevBestBid = bestBid;
        if (prevBestBid * BID_MIN_INCREASE_FACTOR_BPS > _bidAmount * ONE_IN_BPS)
            revert BidTooLow();
        // refund previous bidder if it's not the first bid
        if (cachedTopBidder != address(0))
            goo.transfer(cachedTopBidder, prevBestBid);
        bestBid = uint128(_bidAmount);
        topBidder = msg.sender;
        uint256 minimumEndTime = block.timestamp + AUCTION_GRACE_PERIOD;
        uint256 currentAuctionEnd = auctionEnd;
        auctionEnd = uint64(
            minimumEndTime > currentAuctionEnd
                ? minimumEndTime
                : currentAuctionEnd
        );
    }

    /// @dev check whether auction has finalized
    function checkAuctionEnd()
        public
        onlyState(ThroneState.AuctionInProgress)
        returns (bool)
    {
        if (block.timestamp > auctionEnd) {
            state = ThroneState.Dissolved;
            artGobblers.transferFrom(
                address(this),
                topBidder,
                legendaryGobblerId
            );
            artGobblers.removeGoo(artGobblers.gooBalance(address(this)));
            return true;
        }
        return false;
    }

    /// @dev claim share of GOO produced by the legendary + auction proceeds
    function claimShare(address _recipient)
        external
        onlyState(ThroneState.Dissolved)
    {
        uint256 shares = balanceOf[msg.sender];
        uint256 totalShares = totalSupply;
        uint256 gooShare = (goo.balanceOf(address(this)) * shares) /
            totalShares;
        _burn(msg.sender, shares);
        goo.transfer(_recipient, gooShare);
    }
}
