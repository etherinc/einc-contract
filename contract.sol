pragma solidity ^0.4.16;

contract init {
    bool public status = true;
    uint256 public totalShares;
    uint256 public totalVotingPower = 0;
    uint256 usedShares = 0;
    string public Name;
    uint256 public proposalVotingExpiry = 60;
    uint public founded = now;
    uint256 public minimumVotingPercentage = 51;
    Proposal[] public proposals;
    uint public totalProposals = 0;
    uint public totalMembers = 0;
    string public legalCompany;
    mapping (string => uint) roles;
    mapping (address => bool) public CheckMember;
    mapping (address => Member) public members;
    mapping (address => Investment) allowedInvest;
    mapping (uint => address) public _propTo;
    
    event receivedEther(address sender, uint amount);
    event ProposalAdded(uint proposalID, address recipient, uint amount, string description);
    event Voted(uint proposalID, bool position, address voter, string justification);
    event ProposalResult(uint proposalID, bool result);
    event InvestemtReceived(address member, uint shares);
    event ChangeOfRules(uint debatePeriod, uint256 VotingPercentage);
    event ChangeOfLegalCompany(string LegalCompany);
    
    struct Investment {
        uint shares;
        bool executed;
        uint256 etherAmount;
        uint256 vpower;
        uint256 deadline;
        uint time;
    }
    
    struct Proposal {
        bool executed;
        bool proposalPassed;
        uint error;
        address creator;
        address executor;
        address account;
        uint256 value;
        string proposalType;
        string[] metaData;
        string Description;
        uint votingDeadline;
        uint numberOfVotes;
        uint256 positiveVotes;
        uint256 negativeVotes;
        Vote[] votes;
        mapping (address => bool) voted;
    }
    
    struct Member {
        string name;
        bool isActive;
        uint256 shares;
        uint256 votingPower;
        string role;
        uint memberFrom;
        uint memberTo;
    }
    
    struct Vote {
        bool inSupport;
        address voter;
        string justification;
    }
    
    modifier isActive {
        require(status == true);
        _;
    }
    
    modifier onlyMembers {
        require(CheckMember[msg.sender]);
        _;
    }
    
    function stringToUint256(string s) internal returns (uint256 result) {
        bytes memory b = bytes(s);
        uint i;
        result = 0;
        for (i = 0; i < b.length; i++) {
            uint c = uint(b[i]);
            if (c >= 48 && c <= 57) {
                result = result * 10 + (c - 48);
            }
        }
    }
}

contract eInc is init {
    
    modifier onlyEM {
        Member storage m = members[msg.sender];
        require(getGrade(m.role) < 1000);
        _;
    }
    
    function () payable isActive public {
        Investment storage i = allowedInvest[msg.sender];
        if( !i.executed 
            && i.etherAmount > 0 
            && i.etherAmount == msg.value 
            && now < i.time + (i.deadline * 1 days)
        ) {
            i.executed = true;
            investment(msg.sender, i.shares, i.vpower);
            delete allowedInvest[msg.sender];
        } else {
            receivedEther(msg.sender, msg.value);
        }
    }
    
    function eInc() {
        Name = '{{name}}';
        legalCompany = '{{legalcompany}}';
        totalShares = {{totalshares}};
        roles['ceo'] = 1;
        roles['founder'] = 2;
        Member storage m = members[address(this)];
        m.shares = totalShares;
        
        // addMember({{address}}, '{{name}}', '{{role}}', {{shares}}, {{voting_power}});
    }
    
    function investmentAllowance(
        address _a, uint256 _v, uint256 _s, uint256 _vp
    ) constant returns (bool _sts) {
        Investment storage i = allowedInvest[_a];
        require(i.etherAmount == _v 
            && i.shares == _s 
            && i.vpower == _vp 
            && now < i.time + (i.deadline * 1 days) 
            && !i.executed);
        return true;
    }
    
    function investment(address _i, uint256 _s, uint256 _v) isActive internal {
        totalShares += _s;
        if(!CheckMember[msg.sender]){
            Member storage mO = members[address(this)];
            mO.shares += _s;
            addMember(msg.sender, '', 'investor', _s, _v);
        } else {
            usedShares += _s;
            totalVotingPower += _v * _s;
            Member storage m = members[_i];
            m.votingPower += _v * _s;
            m.shares += _s;
        }
        InvestemtReceived(_i, _s);
    }
    
    function unusedShares() constant returns(uint256 _s) {
        Member storage m = members[address(this)];
        return m.shares;
    }
    
    function getGrade(string role) constant returns(uint _g) {
        if(roles[role] > 0){
            _g = roles[role];
        } else {
            _g = 10000;
        }
        return _g;
    }
    
    function updateDetails(
        address _a, 
        string _n
    ) isActive onlyMembers public {
        require(CheckMember[msg.sender]);
        if(msg.sender != _a){
            require(!CheckMember[_a]);
            delete CheckMember[msg.sender];
            members[_a] = members[msg.sender];
            delete members[msg.sender];
            Member storage newm = members[_a];
            newm.name = _n;
            CheckMember[_a] = true;
        } else {
            Member storage m = members[msg.sender];
            m.name = _n;
        }
    }
    
    function addMember(
        address _a, 
        string _n, 
        string _p, 
        uint256 _s, 
        uint256 _v
    ) isActive internal {
        require(unusedShares() >= _s);
        Member storage mO = members[address(this)];
        mO.shares -= _s;
        usedShares += _s;
        CheckMember[_a] = true; 
        
        Member storage m = members[_a];
        m.role = _p;
        m.name = _n;
        m.votingPower = _v * _s;
        m.shares = _s;
        m.isActive = true;
        m.memberFrom = now;
        
        totalVotingPower += _v * _s;
        totalMembers++;
    }
    
    function newProposal(
        address _a,
        uint256 _v,
        string _t,
        string _m,
        string _m1,
        string _m2,
        string _d,
        address _to
    )
        isActive onlyMembers onlyEM public
        returns (uint pID)
    {
        pID = proposals.length++;
        Proposal storage p = proposals[pID];
        if(keccak256(_t) == keccak256("sell_share")){ _a = msg.sender; }
        p.creator = msg.sender;
        p.account = _a;
        p.value = _v;
        p.Description = _d;
        p.proposalType = _t;
        p.metaData.push(_m);
        p.metaData.push(_m1); 
        p.metaData.push(_m2);  
        p.votingDeadline = now + proposalVotingExpiry * 1 minutes;
        totalProposals++;
        ProposalAdded(pID, _a, _v, _d);
        if(address(this) != _to && _to != address(0)){
            _propTo[pID] = _to;
        }
        return pID;
    }
    
    function vote(
        uint _p,
        bool _r,
        string _c
    )
        isActive onlyMembers public
        returns (uint voteID)
    {
        Proposal storage p = proposals[_p];
        require(!p.voted[msg.sender] 
            && !p.executed
            && now < p.votingDeadline);
        p.voted[msg.sender] = true;
        p.numberOfVotes++;
        Member storage m = members[msg.sender];
        uint256 votingPower = m.votingPower;
        if (_r) { 
            p.positiveVotes += votingPower; 
        } else {
            p.negativeVotes += votingPower; 
        }
        Voted(_p, _r, msg.sender, _c);
        return p.numberOfVotes;
    }
    
    function executeProposal(uint _p) isActive onlyMembers public {
        Proposal storage p = proposals[_p];
        bytes32 eT = keccak256(p.proposalType);
        if(
            eT == keccak256("add_member") || 
            eT == keccak256("remove_member") || 
            eT == keccak256("roles") || 
            eT == keccak256("change_role")
        ){
            emp(_p);
        } else {
            eop(_p);
        }
    }
    
    function emp(uint _p) internal {
        Proposal storage p = proposals[_p];
        require(!p.executed);
        p.executed = true;
        Member storage mA = members[msg.sender];
        
        if (getGrade(mA.role) < getGrade(p.metaData[0]) 
            && getGrade(mA.role) < 1000 
            && mA.isActive) {
            
            if(_propTo[_p] != address(0)){
                intractEinc(_p);
            } else {
                bytes32 eT = keccak256(p.proposalType);
                
                if(eT == keccak256("add_member")){
                    if(!CheckMember[p.account]){
                        addMember(p.account, p.metaData[1], p.metaData[0], 0, 0);
                    } else { p.error = 140; }
                } else if(eT == keccak256("roles")){
                    require(p.value > 1);
                    if(keccak256(p.metaData[0]) != keccak256("ceo")){
                        roles[p.metaData[0]] = p.value;
                    } else {
                        p.error = 136;
                    }
                } else {
                    if(CheckMember[p.account]){
                        if(eT == keccak256("remove_member")){
                            Member storage mI = members[p.account];
                            if(getGrade(mI.role) != 1){
                                mI.isActive = false;
                                mI.memberTo = now;
                                totalMembers--;
                            } else {
                                p.error = 134;
                            }
                        } else if(eT == keccak256("change_role")){
                            Member storage m = members[p.account];
                            if(getGrade(m.role) != 1){
                                m.role = p.metaData[0];
                            } else {
                                p.error = 134;
                            }
                        }
                    } else { p.error = 139; }
                }
            }
            
            p.executor = msg.sender;
            bool psts = true;
            if(p.error > 100){ psts = false; }
            p.proposalPassed = psts;
            ProposalResult(_p, psts);
        } else {
            if(now > p.votingDeadline){
                p.proposalPassed = false;
                ProposalResult(_p, false);
            } else {
                p.executed = false;
            }
        }
    }
    
    function minVotes() internal returns(uint256 _m) {
        return ( totalVotingPower * minimumVotingPercentage ) / 100;
    }
    
    function intractEinc(uint _p) internal {
        Proposal storage p = proposals[_p];
        bytes32 eT = keccak256(p.proposalType);
        
        eInc einc = eInc(_propTo[_p]);
        
        if( eT == keccak256("einc_vote") ){
            bool vR = false;
            if(stringToUint256(p.metaData[0]) == 1){
                vR = true;
            }
            einc.vote(p.value, vR, p.Description);
        } else if( eT == keccak256("einc_execute_proposal") ){
            einc.executeProposal(p.value);
        } else {
            einc.newProposal(p.account, p.value, p.proposalType, 
                p.metaData[0], p.metaData[1], p.metaData[2], p.Description, address(0));
        }
    }
    
    function eop(uint _p) internal {
        Proposal storage p = proposals[_p];
        require(!p.executed);
        p.executed = true;
        uint passed;
        
        if( p.positiveVotes > minVotes()){ passed = 1; } 
        else if( p.negativeVotes > minVotes()){ passed = 2; }
        if (passed == 1) {
            if(_propTo[_p] != address(0)){
                intractEinc(_p);
            } else {
                Member storage mO = members[address(this)];
                bytes32 eT = keccak256(p.proposalType);
                
                if(eT == keccak256("issue_share")){
                    mO.shares += p.value;
                    totalShares += p.value;
                } else if(eT == keccak256("sell_share")){
                    if(CheckMember[p.account]){
                        Member storage mm = members[p.account];
                        uint256 tmpVotingPower1 = p.value * stringToUint256(p.metaData[0]);
                        if(mm.shares >= p.value && mm.votingPower >= tmpVotingPower1){
                            mm.votingPower -= tmpVotingPower1;
                            mm.shares -= p.value;
                            mO.shares += p.value;
                            usedShares -= p.value;
                        } else {
                            p.error = 137;
                        }
                    } else { p.error = 139; }
                } else if(eT == keccak256("investment")){
                    Investment storage inv = allowedInvest[p.account];
                    inv.shares = p.value;
                    inv.etherAmount = stringToUint256(p.metaData[1]);
                    inv.vpower = stringToUint256(p.metaData[0]);
                    inv.deadline = stringToUint256(p.metaData[2]);
                    inv.time = now;
                } else if(eT == keccak256("payment")){
                    if(keccak256(p.metaData[0]) == keccak256("einc")){
                        if(!p.account.call.value(p.value).gas(stringToUint256(p.metaData[1]))()){ p.error = 142; }
                    } else {
                        if(!p.account.send(p.value)){ p.error = 138; }
                    }
                } else if(eT == keccak256("change_legalcompany")){
                    legalCompany = p.metaData[0];
                    ChangeOfLegalCompany(legalCompany);
                } else if(eT == keccak256("voting_rule")){
                    if(p.value > 50){
                        minimumVotingPercentage = p.value;
                        proposalVotingExpiry = stringToUint256(p.metaData[0]);
                        ChangeOfRules(proposalVotingExpiry, minimumVotingPercentage);
                    } else { p.error = 141; }
                } else if(eT == keccak256("close_einc")){
                    status = false;
                } else if(eT != keccak256("proposal")){
                    if(CheckMember[p.account]){
                        if(eT == keccak256("appoint_ceo")){
                            Member storage m2 = members[p.account];
                            m2.role = 'ceo';
                        } else if(eT == keccak256("fire_ceo")){
                            Member storage m3 = members[p.account];
                            m3.role = p.metaData[0];
                        } else if(eT == keccak256("assign_share")){
                            if(unusedShares() >= p.value){
                                Member storage m = members[p.account];
                                mO.shares -= p.value;
                                m.shares += p.value;
                                m.votingPower += p.value * stringToUint256(p.metaData[0]);
                                usedShares += p.value;
                                totalVotingPower += p.value * stringToUint256(p.metaData[0]);
                            } else { p.error = 137; }
                        }
                    } else { p.error = 139; }
                }
            }
            
            bool psts = true;
            p.executor = msg.sender;
            if(p.error > 100){ psts = false; }
            p.proposalPassed = psts;
            ProposalResult(_p, psts);
        } else {
            if(now > p.votingDeadline || passed == 2){
                p.proposalPassed = false;
                ProposalResult(_p, false);
            } else {
                p.executed = false;
            }
        }
    }
}
