// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/utils/EnumerableSet.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./VoltToken.sol";

// MasterChefFuseFi is a boss. He says "go f your blocks lego boy, I'm gonna use timestamp instead".
// And to top it off, it takes no risks. Because the biggest risk is operator error.
// So we make it virtually impossible for the operator of this contract to cause a bug with people's harvests.
//
// Note that it's ownable and the owner wields tremendous power. The ownership
// will be transferred to a governance smart contract once VOLT is sufficiently
// distributed and the community can show to govern itself.
//
// With thanks to the Lydia Finance team.
//
// Godspeed and may the 10x be with you.
contract MasterChefFuseFi is Ownable {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    // Info of each user.
    struct UserInfo {
        uint256 amount; // How many LP tokens the user has provided.
        uint256 rewardDebt; // Reward debt. See explanation below.
        //
        // We do some fancy math here. Basically, any point in time, the amount of VOLTs
        // entitled to a user but is pending to be distributed is:
        //
        //   pending reward = (user.amount * pool.accVoltPerShare) - user.rewardDebt
        //
        // Whenever a user deposits or withdraws LP tokens to a pool. Here's what happens:
        //   1. The pool's `accVoltPerShare` (and `lastRewardTimestamp`) gets updated.
        //   2. User receives the pending reward sent to his/her address.
        //   3. User's `amount` gets updated.
        //   4. User's `rewardDebt` gets updated.
    }

    // Info of each pool.
    struct PoolInfo {
        IERC20 lpToken; // Address of LP token contract.
        uint256 allocPoint; // How many allocation points assigned to this pool. VOLTs to distribute per second.
        uint256 lastRewardTimestamp; // Last timestamp that VOLTs distribution occurs.
        uint256 accVoltPerShare; // Accumulated VOLTs per share, times 1e12. See below.
    }

    // The VOLT TOKEN!
    VoltToken public volt;
    // Dev address.
    address public devaddr;
    // Treasury address.
    address public treasuryaddr;
    // VOLT tokens created per second.
    uint256 public voltPerSec;
    // Percentage of pool rewards that goto the devs.
    uint256 public devPercent; // 20%
    // Percentage of pool rewards that goes to the treasury.
    uint256 public treasuryPercent; // 20%

    // Info of each pool.
    PoolInfo[] public poolInfo;
    // Mapping to check which LP tokens have been added as pools.
    mapping(IERC20 => bool) public isPool;
    // Info of each user that stakes LP tokens.
    mapping(uint256 => mapping(address => UserInfo)) public userInfo;
    // Total allocation points. Must be the sum of all allocation points in all pools.
    uint256 public totalAllocPoint = 0;
    // The timestamp when VOLT mining starts.
    uint256 public startTimestamp;

    event Add(address indexed lpToken, uint256 allocPoint);
    event Set(uint256 indexed pid, uint256 allocPoint);
    event Deposit(address indexed user, uint256 indexed pid, uint256 amount);
    event Withdraw(address indexed user, uint256 indexed pid, uint256 amount);
    event EmergencyWithdraw(address indexed user, uint256 indexed pid, uint256 amount);
    event SetDevAddress(address indexed oldAddress, address indexed newAddress);
    event UpdateEmissionRate(address indexed user, uint256 _voltPerSec);

    constructor(
        VoltToken _volt,
        address _devaddr,
        address _treasuryaddr,
        uint256 _voltPerSec,
        uint256 _startTimestamp,
        uint256 _devPercent,
        uint256 _treasuryPercent
    ) public {
        require(0 <= _devPercent && _devPercent <= 1000, "constructor: invalid dev percent value");
        require(0 <= _treasuryPercent && _treasuryPercent <= 1000, "constructor: invalid treasury percent value");
        require(_devPercent + _treasuryPercent <= 1000, "constructor: total percent over max");
        volt = _volt;
        devaddr = _devaddr;
        treasuryaddr = _treasuryaddr;
        voltPerSec = _voltPerSec;
        startTimestamp = _startTimestamp;
        devPercent = _devPercent;
        treasuryPercent = _treasuryPercent;
    }

    function poolLength() external view returns (uint256) {
        return poolInfo.length;
    }

    // Add a new lp to the pool. Can only be called by the owner.
    // XXX DO NOT add the same LP token more than once. Rewards will be messed up if you do.
    function add(uint256 _allocPoint, IERC20 _lpToken) public onlyOwner {
        require(!isPool[_lpToken], "add: LP already added");
        massUpdatePools();
        uint256 lastRewardTimestamp = block.timestamp > startTimestamp ? block.timestamp : startTimestamp;
        totalAllocPoint = totalAllocPoint.add(_allocPoint);
        poolInfo.push(
            PoolInfo({
                lpToken: _lpToken,
                allocPoint: _allocPoint,
                lastRewardTimestamp: lastRewardTimestamp,
                accVoltPerShare: 0
            })
        );
        isPool[_lpToken] = true;
        emit Add(address(_lpToken), _allocPoint);
    }

    // Update the given pool's VOLT allocation point. Can only be called by the owner.
    function set(uint256 _pid, uint256 _allocPoint) public onlyOwner {
        massUpdatePools();
        totalAllocPoint = totalAllocPoint.sub(poolInfo[_pid].allocPoint).add(_allocPoint);
        poolInfo[_pid].allocPoint = _allocPoint;
        emit Set(_pid, _allocPoint);
    }

    // View function to see pending VOLTs on frontend.
    function pendingVolt(uint256 _pid, address _user) external view returns (uint256) {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][_user];
        uint256 accVoltPerShare = pool.accVoltPerShare;
        uint256 lpSupply = pool.lpToken.balanceOf(address(this));
        if (block.timestamp > pool.lastRewardTimestamp && lpSupply != 0) {
            uint256 multiplier = block.timestamp.sub(pool.lastRewardTimestamp);
            uint256 voltReward = multiplier
                .mul(voltPerSec)
                .mul(pool.allocPoint)
                .div(totalAllocPoint)
                .mul(1000 - devPercent - treasuryPercent)
                .div(1000);
            accVoltPerShare = accVoltPerShare.add(voltReward.mul(1e12).div(lpSupply));
        }
        return user.amount.mul(accVoltPerShare).div(1e12).sub(user.rewardDebt);
    }

    // Update reward variables for all pools. Be careful of gas spending!
    function massUpdatePools() public {
        uint256 length = poolInfo.length;
        for (uint256 pid = 0; pid < length; ++pid) {
            updatePool(pid);
        }
    }

    // Update reward variables of the given pool to be up-to-date.
    function updatePool(uint256 _pid) public {
        PoolInfo storage pool = poolInfo[_pid];
        if (block.timestamp <= pool.lastRewardTimestamp) {
            return;
        }
        uint256 lpSupply = pool.lpToken.balanceOf(address(this));
        if (lpSupply == 0) {
            pool.lastRewardTimestamp = block.timestamp;
            return;
        }
        uint256 multiplier = block.timestamp.sub(pool.lastRewardTimestamp);
        uint256 voltReward = multiplier.mul(voltPerSec).mul(pool.allocPoint).div(totalAllocPoint);
        uint256 lpPercent = 1000 - devPercent - treasuryPercent;
        volt.mint(devaddr, voltReward.mul(devPercent).div(1000));
        volt.mint(treasuryaddr, voltReward.mul(treasuryPercent).div(1000));
        volt.mint(address(this), voltReward.mul(lpPercent).div(1000));
        pool.accVoltPerShare = pool.accVoltPerShare.add(voltReward.mul(1e12).div(lpSupply).mul(lpPercent).div(1000));
        pool.lastRewardTimestamp = block.timestamp;
    }

    // Deposit LP tokens to MasterChef for VOLT allocation.
    function deposit(uint256 _pid, uint256 _amount) public {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        updatePool(_pid);
        if (user.amount > 0) {
            uint256 pending = user.amount.mul(pool.accVoltPerShare).div(1e12).sub(user.rewardDebt);
            safeVoltTransfer(msg.sender, pending);
        }
        pool.lpToken.safeTransferFrom(address(msg.sender), address(this), _amount);
        user.amount = user.amount.add(_amount);
        user.rewardDebt = user.amount.mul(pool.accVoltPerShare).div(1e12);
        emit Deposit(msg.sender, _pid, _amount);
    }

    // Withdraw LP tokens from MasterChef.
    function withdraw(uint256 _pid, uint256 _amount) public {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        require(user.amount >= _amount, "withdraw: not good");

        updatePool(_pid);
        uint256 pending = user.amount.mul(pool.accVoltPerShare).div(1e12).sub(user.rewardDebt);
        safeVoltTransfer(msg.sender, pending);
        user.amount = user.amount.sub(_amount);
        pool.lpToken.safeTransfer(address(msg.sender), _amount);
        user.rewardDebt = user.amount.mul(pool.accVoltPerShare).div(1e12);
        emit Withdraw(msg.sender, _pid, _amount);
    }

    // Withdraw without caring about rewards. EMERGENCY ONLY.
    function emergencyWithdraw(uint256 _pid) public {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        pool.lpToken.safeTransfer(address(msg.sender), user.amount);
        emit EmergencyWithdraw(msg.sender, _pid, user.amount);
        user.amount = 0;
        user.rewardDebt = 0;
    }

    // Safe volt transfer function, just in case if rounding error causes pool to not have enough VOLTs.
    function safeVoltTransfer(address _to, uint256 _amount) internal {
        uint256 voltBal = volt.balanceOf(address(this));
        if (_amount > voltBal) {
            volt.transfer(_to, voltBal);
        } else {
            volt.transfer(_to, _amount);
        }
    }

    // Update dev address by the previous dev.
    function dev(address _devaddr) public {
        require(msg.sender == devaddr, "dev: wut?");
        devaddr = _devaddr;
        emit SetDevAddress(msg.sender, _devaddr);
    }

    function setDevPercent(uint256 _newDevPercent) public onlyOwner {
        require(0 <= _newDevPercent && _newDevPercent <= 1000, "setDevPercent: invalid percent value");
        require(treasuryPercent + _newDevPercent <= 1000, "setDevPercent: total percent over max");
        devPercent = _newDevPercent;
    }

    function setTreasuryPercent(uint256 _newTreasuryPercent) public onlyOwner {
        require(0 <= _newTreasuryPercent && _newTreasuryPercent <= 1000, "setTreasuryPercent: invalid percent value");
        require(devPercent + _newTreasuryPercent <= 1000, "setTreasuryPercent: total percent over max");
        treasuryPercent = _newTreasuryPercent;
    }

    // Pancake has to add hidden dummy pools inorder to alter the emission,
    // here we make it simple and transparent to all.
    function updateEmissionRate(uint256 _voltPerSec) public onlyOwner {
        massUpdatePools();
        voltPerSec = _voltPerSec;
        emit UpdateEmissionRate(msg.sender, _voltPerSec);
    }
}
