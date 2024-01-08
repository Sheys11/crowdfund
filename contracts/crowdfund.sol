//SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import "./PriceConverter.sol";

error NotOwner();

contract Crowdfund {
    using PriceConverter for uint256;

    uint256 public constant MINIMUM_USD = 5 * 1e18; //$5

    uint256 public constant FUND_TARGET = 1e24; //$1 Million

    uint256 public constant FUND_DURATION = 3 weeks;

    address public beneficiaryAccount;
    address public admin;

    address[] public funders;
    mapping(address => bool) sponsor;
    mapping(address => uint256) public addressToAmountFunded;

    uint256 fundBalance;

    event Funded(
        address indexed funder,
        uint256 indexed fundAmountInUsd,
        uint256 indexed fundBalance
    );
    event Withdrawn(
        uint256 indexed unaccountedFunds,
        uint256 indexed fundBalance
    );
    event BeneficiaryAccountChanged(
        address indexed beneficiaryAccount,
        address indexed newBeneficiaryAccount
    );
    event AdminChanged(address indexed oldAddress, address indexed newAddress);

    constructor(address _beneficiary) {
        admin = msg.sender;
        beneficiaryAccount = _beneficiary;
    }

    modifier onlyAdmin() {
        if (msg.sender != admin) revert NotOwner();
        _;
    }

    function fund() public payable {
        uint256 fundAmountInUsd = msg.value.getConversionRate();
        require(fundAmountInUsd > MINIMUM_USD, "Value too low");
        require(
            getAccountedFunds() + fundAmountInUsd <= FUND_TARGET,
            "Funding over threshold!"
        );
        require(block.timestamp <= FUND_DURATION, "Auction status: Ended");
        //keep records of funders and the amount funded
        if (!sponsor[msg.sender]) {
            funders.push(msg.sender);
            sponsor[msg.sender] = true;
        }
        addressToAmountFunded[msg.sender] += msg.value;
        fundBalance += msg.value;

        emit Funded(
            msg.sender,
            fundAmountInUsd,
            fundBalance.getConversionRate()
        );
    }

    function withdraw() public onlyAdmin {
        //require(getAccountedFunds() >= FUND_TARGET);
        require(
            block.timestamp >= FUND_DURATION,
            "Auction status: Still Active"
        );

        //payable(beneficiaryAccount).safeTransfer(address(this).balance);

        (bool success, ) = payable(beneficiaryAccount).call{value: address(this).balance}("");

        require(success, "Call failed");

        uint256 fundBalanceInUsd = fundBalance.getConversionRate();
        uint256 unaccountedFundsInUsd = fundBalanceInUsd - getAccountedFunds();

        emit Withdrawn(unaccountedFundsInUsd, fundBalanceInUsd);

        fundBalance = 0;
    }

    //Added receive and fallback functions to ensure successful tx with funders who sent money without the fund function.
    receive() external payable {
        fund();
    }

    fallback() external payable {
        fund();
    }

    //          SETTERS                 //

    function changeBeneficiaryAccount(
        address newBeneficiaryAccount
    ) public onlyAdmin {
        require(newBeneficiaryAccount != address(0), "Invalid address");
        beneficiaryAccount = newBeneficiaryAccount;
        emit BeneficiaryAccountChanged(
            beneficiaryAccount,
            newBeneficiaryAccount
        );
    }

    function changeAdmin(address newAdmin) public onlyAdmin {
        require(newAdmin != address(0), "Invalid address");

        admin = newAdmin;
        emit AdminChanged(admin, newAdmin);
    }

    //              GETTERS                 //

    function getAccountedFunds() public view returns (uint256) {
        uint256 accountedFunds;

        for (uint256 i; i < funders.length; i++) {
            accountedFunds += addressToAmountFunded[funders[i]];
        }
        return accountedFunds.getConversionRate();
    }

    function getTotalFunders() external view returns (uint256) {
        return funders.length;
    }

    function getFundBalance() public view returns (uint256) {
        return fundBalance.getConversionRate();
    }
}
