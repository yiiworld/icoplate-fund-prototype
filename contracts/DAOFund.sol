pragma solidity ^0.4.15;

import './IDAOToken.sol';


/// @title ICO fund controlled by the investors
contract DAOFund {

    enum ApprovalState {
        NotVoted,
        Approval,
        Disapproval
    }

    // Decision point description for the DAO
    struct KeyPoint {
        // duration of the period which is evaluated at this point
        uint duration;

        // funds share percent to be transfered to the project at this keypoint
        uint fundsShare;
    }

    // Dynamic state of a KeyPoint
    struct KeyPointState {
        bool processed;

        // true iff decision was made to further finance the project
        bool success;

        uint votingEndTime;

        uint approvalVotes;
        uint disapprovalVotes;
        mapping(address => ApprovalState) approvalState;
    }


    // event fired when the DAO comes to conclusion about a KeyPoint
    event KeyPointResolved(uint keyPointIndex, bool success);


    modifier onlyActive {
        require(isActive());
        _;
    }

    modifier onlyTokenHolder {
        require(m_token.balanceOf(msg.sender) > 0);
        _;
    }


    // PUBLIC interface

    function DAOFund(IDAOToken token){
        m_token = token;

        m_keyPoints.push(KeyPoint({duration: 20 weeks, fundsShare: 25}));
        m_keyPoints.push(KeyPoint({duration: 40 weeks, fundsShare: 45}));
        m_keyPoints.push(KeyPoint({duration: 20 weeks, fundsShare: 30}));

        validateKeyPoints();

        // first tranche after the ICO
        m_keyPointState.push(createKeyPointState(now));
        m_keyPointState[0].processed = true;
        m_keyPointState[0].success = true;
        KeyPointResolved(0, true);
        initNextKeyPoint();

        assert(isActive());
    }

    function approveKeyPoint(bool approval) external onlyActive onlyTokenHolder {
        KeyPointState storage state = getCurrentKeyPointState();
        require(now < state.votingEndTime);
        require(state.approvalState[msg.sender] == ApprovalState.NotVoted);

        if (approval) {
            state.approvalState[msg.sender] = ApprovalState.Approval;
            state.approvalVotes += m_token.balanceOf(msg.sender);
        } else {
            state.approvalState[msg.sender] = ApprovalState.Disapproval;
            state.disapprovalVotes += m_token.balanceOf(msg.sender);
        }
    }


    // INTERNALS

    function validateKeyPoints() private constant {
        assert(m_keyPoints.length > 1);
        uint fundsTotal;
        for (uint i = 0; i < m_keyPoints.length; i++) {
            KeyPoint storage keyPoint = m_keyPoints[i];

            assert(keyPoint.duration >= 1 weeks);
            fundsTotal += keyPoint.fundsShare;
        }
        assert(100 == fundsTotal);
    }

    function isActive() private constant returns (bool) {
        assert(m_keyPoints.length >= m_keyPointState.length);
        return m_keyPoints.length > m_keyPointState.length
                || m_keyPoints.length == m_keyPointState.length && !(m_keyPointState[m_keyPointState.length - 1].processed);
    }

    function initNextKeyPoint() private {
        assert(m_keyPoints.length > m_keyPointState.length);

        KeyPoint storage keyPoint = m_keyPoints[m_keyPointState.length];
        m_keyPointState.push(createKeyPointState(now + keyPoint.duration));
    }


    function getCurrentKeyPoint() private constant returns (KeyPoint storage) {
        assert(isActive());
        return m_keyPoints[m_keyPointState.length - 1];
    }

    function getCurrentKeyPointState() private constant returns (KeyPointState storage) {
        assert(isActive());
        return m_keyPointState[m_keyPointState.length - 1];
    }

    function createKeyPointState(uint votingEndTime) private constant returns (KeyPointState memory) {
        return KeyPointState({processed: false, success: false,
                votingEndTime: votingEndTime, approvalVotes: 0, disapprovalVotes: 0});
    }


    // FIELDS

    IDAOToken public m_token;

    KeyPoint[] public m_keyPoints;
    KeyPointState[] public m_keyPointState;
}