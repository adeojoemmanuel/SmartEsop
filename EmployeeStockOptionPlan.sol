// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title EmployeeStockOptionPlan
 * @dev A smart contract for managing an Employee Stock Option Plan (ESOP) on the Ethereum blockchain.
 */
contract EmployeeStockOptionPlan {
    address public owner;

    struct VestingSchedule {
        uint256 totalOptions;
        uint256 vestingDuration;
        uint256 cliffDuration;
        uint256 startTime;
        uint256 endTime;
        bool transferable;
    }

    mapping(address => uint256) private vestedOptions;
    mapping(address => uint256) private exercisedOptions;
    mapping(address => VestingSchedule) private vestingSchedules;

    event StockOptionsGranted(address indexed employee, uint256 options);
    event VestingScheduleSet(address indexed employee, uint256 totalOptions, uint256 vestingDuration, uint256 cliffDuration, bool transferable);
    event OptionsExercised(address indexed employee, uint256 options);

    modifier onlyOwner() {
        require(msg.sender == owner, "Only contract owner can call this function");
        _;
    }

    modifier onlyEmployee() {
        require(vestingSchedules[msg.sender].totalOptions > 0, "Only eligible employees can call this function");
        _;
    }

    /**
     * @dev Initializes the contract and sets the contract owner.
     */
    constructor() {
        owner = msg.sender;
    }

    /**
     * @dev Grants stock options to an employee.
     * @param employee The address of the employee.
     * @param options The number of options to be granted.
     */
    function grantStockOptions(address employee, uint256 options) external onlyOwner {
        require(options > 0, "Options count must be greater than zero");
        vestedOptions[employee] += options;
        emit StockOptionsGranted(employee, options);
    }

    /**
     * @dev Sets the vesting schedule for an employee's options.
     * @param employee The address of the employee.
     * @param totalOptions The total number of options for the employee.
     * @param vestingDuration The duration of the vesting period in seconds.
     * @param cliffDuration The duration of the cliff period in seconds.
     * @param transferable Whether the options are transferable.
     */
    function setVestingSchedule(
        address employee,
        uint256 totalOptions,
        uint256 vestingDuration,
        uint256 cliffDuration,
        bool transferable
    ) external onlyOwner {
        require(totalOptions > 0, "Total options must be greater than zero");
        require(vestingDuration > 0, "Vesting duration must be greater than zero");
        require(cliffDuration < vestingDuration, "Cliff duration must be less than vesting duration");

        VestingSchedule storage vestingSchedule = vestingSchedules[employee];
        vestingSchedule.totalOptions = totalOptions;
        vestingSchedule.vestingDuration = vestingDuration;
        vestingSchedule.cliffDuration = cliffDuration;
        vestingSchedule.startTime = block.timestamp;
        vestingSchedule.endTime = block.timestamp + vestingDuration;
        vestingSchedule.transferable = transferable;

        emit VestingScheduleSet(employee, totalOptions, vestingDuration, cliffDuration, transferable);
    }

    /**
     * @dev Allows an employee to exercise their vested options.
     * @param options The number of options to be exercised.
     */
    function exerciseOptions(uint256 options) external onlyEmployee {
        require(options > 0, "Options count must be greater than zero");

        VestingSchedule storage vestingSchedule = vestingSchedules[msg.sender];
        require(block.timestamp >= vestingSchedule.startTime, "Options are not yet vested");

        uint256 vestedCount = getVestedOptions(msg.sender);
        uint256 availableOptions = vestedCount - exercisedOptions[msg.sender];
        require(options <= availableOptions, "Insufficient vested options");

        exercisedOptions[msg.sender] += options;
        emit OptionsExercised(msg.sender, options);
    }

    /**
     * @dev Retrieves the number of vested options for an employee.
     * @param employee The address of the employee.
     * @return The number of vested options.
     */
    function getVestedOptions(address employee) public view returns (uint256) {
        VestingSchedule storage vestingSchedule = vestingSchedules[employee];

        if (block.timestamp < vestingSchedule.startTime + vestingSchedule.cliffDuration) {
            return 0;
        }

        if (block.timestamp >= vestingSchedule.endTime) {
            return vestingSchedule.totalOptions;
        }

        uint256 elapsedTime = block.timestamp - vestingSchedule.startTime;
        uint256 vestedCount = vestingSchedule.totalOptions * elapsedTime / vestingSchedule.vestingDuration;
        return vestedCount;
    }

    /**
     * @dev Retrieves the number of exercised options for an employee.
     * @param employee The address of the employee.
     * @return The number of exercised options.
     */
    function getExercisedOptions(address employee) public view returns (uint256) {
        return exercisedOptions[employee];
    }

    /**
     * @dev Allows an employee to transfer their vested options to another eligible employee.
     * @param to The address of the recipient.
     * @param options The number of options to be transferred.
     */
    function transferOptions(address to, uint256 options) external onlyEmployee {
        require(vestingSchedules[msg.sender].transferable, "Options are not transferable");
        require(options > 0, "Options count must be greater than zero");
        require(options <= vestedOptions[msg.sender] - exercisedOptions[msg.sender], "Insufficient vested options");

        vestedOptions[msg.sender] -= options;
        vestedOptions[to] += options;
    }
}
