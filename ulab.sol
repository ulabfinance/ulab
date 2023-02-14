// SPDX-License-Identifier: MIT
pragma solidity 0.8.8;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';

interface IToken {
    function decimals() external view returns (uint8);
}

contract PartnerContract is Initializable {
     //（0-认购中,1-已完成）
    enum partnerStatus{UnderSubscription,Completed}

     //(0-参与者,1-创建者)
    enum PartnerJoinStatus{Joiner,creator}

    //合伙人
    struct Partner {
        uint256  quota;             //认购名额
        uint256  completedQuota;    //完成名额
        uint256  amount;            //认购金额
    }

    struct PartnerInfo {
        address  creator;           //创建者
        uint256  partnerId;         //合伙人id
        uint256  periods;           //第几期
        uint256  value;            //所需金额
        uint256  joinValue;        //已参与金额
        uint256  number;            //已参与人数
        uint256 stime;              //创建时间
        uint256 etime;              //完成时间
        partnerStatus status;       //状态（0-认购中,1-已完成）
    }

    mapping(uint256=>PartnerInfo) public partnerInfos;

    mapping(uint256=>Partner) public partners;

    uint256 private partnerId;

    uint256 private joinPartnerId;

    uint256 public currentPeriods;

    address private usdt;

    uint256 private usdtDecimal;

    address public _owner;

    mapping(address=>bool) public partnerUser;

    uint8 private completeNumber;

    mapping(uint256=>uint256) private partnerTime;

    uint256 private endTime;

    address public receiverAddr;

    event PartnerCreate(uint256 id,uint256 periodId,address account,string name,string desc,uint256 value,uint256 joinValue,uint256 time,uint256 ctime,partnerStatus statu);

    event PartnerComplete(uint256 id,uint8 completeNumber,uint256 time);

    event PartnerJoin(uint256 id,uint256 partnerCreateId,address account,uint256 joinValue,uint256 time,PartnerJoinStatus type_);

    event PartnerJoinValue(uint256 id,uint256 joinValue);

    event PartnerEnd(uint256 time);

    event PeriodsEnd(uint256 periods,uint256 time);

    modifier onlyOwner{
        require(_owner == msg.sender,"onlyOwner");
        _;
    }

    function initialize() external initializer {
        _owner = msg.sender;

    }

    function setPartnerInfo(address _usdt,address _receiverAddr) public onlyOwner {
        usdt = _usdt;
        usdtDecimal = IToken(usdt).decimals();

        Partner memory _partner0 = partners[0];
        _partner0.quota = 20;
        //  _partner0.quota = 2;
        _partner0.amount = 10000 * 10 ** usdtDecimal;
        // _partner0.amount = 200 * 10 ** usdtDecimal;
        partners[0] = _partner0;

        Partner memory _partner1 = partners[1];
        _partner1.quota = 30;
        // _partner1.quota = 3;
        _partner1.amount = 12000 * 10 ** usdtDecimal;
        //  _partner1.amount = 120 * 10 ** usdtDecimal;
        partners[1] = _partner1;

        Partner memory _partner2 = partners[2];
        _partner2.quota = 50;
        // _partner2.quota = 5;
        _partner2.amount = 15000 * 10 ** usdtDecimal;
        //  _partner2.amount = 150 * 10 ** usdtDecimal;
        partners[2] = _partner2;

        receiverAddr = _receiverAddr;

        currentPeriods = 1;

        completeNumber = 1;

        partnerId = 1;

        joinPartnerId = 1;

        partnerTime[currentPeriods] = block.timestamp;
    }

    //_type 0: 50%  1: 100%
    function createPartner(string calldata  _name,string  calldata _desc,uint256 _type,uint256 _value) external {
        require(_type == 0 || _type == 1,"error _type");
        require(endTime == 0,"end");

        uint256 _amount = partners[currentPeriods-1].amount;

        if(_type == 0) {
            require(_value * 2 == _amount,"error value");
        }else{
            require(_value == _amount,"error value");
        }

        require(!partnerUser[msg.sender],"created");

        partnerUser[msg.sender] = true;

        IERC20(usdt).transferFrom(msg.sender,receiverAddr,_value);  

        PartnerInfo memory _partnerInfo = partnerInfos[partnerId];
        _partnerInfo.creator = msg.sender;
        _partnerInfo.partnerId = partnerId;
        _partnerInfo.periods = currentPeriods;
        _partnerInfo.value = _amount;
        _partnerInfo.joinValue = _value;
        _partnerInfo.number = 1;
        _partnerInfo.stime = block.timestamp;

        if(_type == 1) {
            _partnerInfo.etime = block.timestamp;
            _partnerInfo.status = partnerStatus.Completed;
        }else{
            _partnerInfo.status = partnerStatus.UnderSubscription;
        }

        partnerInfos[partnerId] = _partnerInfo;

        emit PartnerCreate(partnerId,currentPeriods,msg.sender,_name,_desc,_amount,_partnerInfo.joinValue,block.timestamp,_partnerInfo.etime,_partnerInfo.status);

        emit PartnerJoin(joinPartnerId,partnerId,msg.sender,_value,block.timestamp,PartnerJoinStatus.creator);

        if(_type == 1) {
            Partner memory _partner = partners[currentPeriods-1]; 

            _partner.completedQuota++;
            partners[currentPeriods-1] =   _partner;    

            if(_partner.quota == _partner.completedQuota) {
                emit PeriodsEnd(currentPeriods,block.timestamp);

                currentPeriods++;

                partnerTime[currentPeriods] = block.timestamp;

                if(currentPeriods == 4) {
                    currentPeriods--;

                    endTime = block.timestamp;
                    emit PartnerEnd(block.timestamp);
                }
            }

            emit PartnerComplete(partnerId,completeNumber,block.timestamp);   
            completeNumber++;   
        }

        partnerId++;
        joinPartnerId++;
    }

    function joinPartner(uint256 _partnerId,uint256 _value) external {
        require(endTime == 0,"end");
        
        PartnerInfo memory _partnerInfo = partnerInfos[_partnerId];
    
        if(_partnerInfo.periods != currentPeriods) {
            _partnerInfo.periods = currentPeriods;
            _partnerInfo.value = partners[currentPeriods-1].amount;
        }

        require(_partnerInfo.value - _partnerInfo.joinValue >= _value,"error _value");

        IERC20(usdt).transferFrom(msg.sender,receiverAddr,_value);      
        
        _partnerInfo.joinValue += _value;
        _partnerInfo.number++;
        
        if(_partnerInfo.joinValue == _partnerInfo.value) {
             _partnerInfo.etime = block.timestamp;
            _partnerInfo.status = partnerStatus.Completed;

            Partner memory _partner = partners[currentPeriods-1]; 

            _partner.completedQuota++;
            partners[currentPeriods-1] =   _partner;   

            if(_partner.quota == _partner.completedQuota) {
                emit PeriodsEnd(currentPeriods,block.timestamp);

                currentPeriods++;

                partnerTime[currentPeriods] = block.timestamp;

                if(currentPeriods == 4) {
                    currentPeriods--;
                    endTime = block.timestamp;

                    emit PartnerEnd(block.timestamp);
                }
            }

            emit PartnerComplete(_partnerId,completeNumber,block.timestamp);  
            completeNumber++;
        }

        partnerInfos[_partnerId] = _partnerInfo;

        emit PartnerJoinValue(_partnerId,_partnerInfo.joinValue);

        emit PartnerJoin(joinPartnerId,_partnerId,msg.sender,_value,block.timestamp,PartnerJoinStatus.Joiner);

         joinPartnerId++;
    }

    function getPartnerTime() view external returns(uint256 time,uint256 periods,uint256 partnerEndtime) {
        time = partnerTime[currentPeriods];
        periods = currentPeriods;
        partnerEndtime = endTime;
    }
}   