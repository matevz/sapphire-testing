// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.4.0
pragma solidity ^0.8.20;

import "@oasisprotocol/sapphire-contracts/contracts/Sapphire.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IWROSE} from "./IWROSE.sol";
import {WROSE} from "./WROSE.sol";
import {ILuminexRouterV1} from "./ILuminexRouterV1.sol";
import {LuminexRouterV1} from "./LuminexRouterV1.sol";

contract MyToken is ERC20, Ownable {
    constructor()
        ERC20("MyToken", "MTK")
        Ownable(msg.sender)
    {}

    function mint(address to, uint256 amount) public onlyOwner {
        _mint(to, amount);
    }
}

contract MyTokenSelfDestruct is ERC20, Ownable {
    constructor()
    ERC20("MyTokenSelfDestruct", "MTK")
    Ownable(msg.sender)
    {}

    function mint(address to, uint256 amount) public onlyOwner {
        _mint(to, amount);
    }

    function destroy() public onlyOwner {
        selfdestruct(payable(owner()));
    }
}

contract MyTokenIndirect is ERC20, Ownable {
    constructor()
    ERC20("MyTokenIndirect", "MTK")
    Ownable(msg.sender)
    {}

    function mint(address to, uint256 amount) public onlyOwner {
        _mint(to, amount);
    }

    function proxyTest(address anotherToken) public onlyOwner {
        uint160 at2 = uint160(anotherToken);
        //at2 -= 100;
        IERC20(address(at2)).transfer(msg.sender,10);
    }
}

contract MyTokenLuminex is ERC20, Ownable {
    using SafeERC20 for IERC20;

    bytes32[] private _ringKeys;
    uint256 private _lastRingKeyUpdate;
    mapping (bytes32 => address) _dataHashToSender;
    ILuminexRouterV1 public swapRouter;
    WROSE public wrose;

    constructor()
    ERC20("MyTokenLuminex", "MTK")
    Ownable(msg.sender)
    {
        wrose = new WROSE();
        swapRouter = new LuminexRouterV1(address(0), address(wrose));
    }

    function proxyPassExt(address token, uint256 amount, bytes memory encodedParams) external payable {
        return proxyPass(token, amount, encodedParams);
    }

    function updateRingKey() external {
        for (uint256 i=0; i<100; i++) {
            _updateRingKey(keccak256(abi.encodePacked("ab", uint256(1), "WROSE", uint256(500))));
        }
    }

    function proxyPass(address token, uint256 amount, bytes memory encodedParams) public payable {
        uint256 feesValue = msg.value;
//        if (token == swapRouter.WROSE()) {
//            require(msg.value >= amount, "Insufficient native amount");
//            IWROSE(swapRouter.WROSE()).deposit{value: amount}();
//            feesValue -= amount;
//        } else {
//            IERC20(token).safeTransferFrom(msg.sender, address(this), amount);
//        }

        (, bytes memory data) = _decrypt(encodedParams);
        _dataHashToSender[keccak256(data)] = msg.sender;

        require(_handleProxyPass(data, amount, token, feesValue) != false, "Failed");
    }

    function _decrypt(bytes memory _keyData) private view returns (uint256 ringKeyIndex, bytes memory output) {
        (uint256 _ringKeyIndex, bytes memory _encryptedData) = abi.decode(_keyData, (uint256, bytes));
        require(_ringKeyIndex < _ringKeys.length, "No ring key found");

        bytes32 nonce = _computeNonce(_ringKeyIndex);

        output = Sapphire.decrypt(_ringKeys[_ringKeyIndex], nonce, _encryptedData, "ILLUMINEX_V1");
        ringKeyIndex = _ringKeyIndex;
    }

    function encryptPayload(bytes memory payload) private view returns (bytes memory encryptedData, uint256 keyIndex) {
        require(_ringKeys.length > 0, "No ring keys set up");

        keyIndex = _ringKeys.length - 1;
        bytes32 nonce = _computeNonce(keyIndex);
        encryptedData = Sapphire.encrypt(_ringKeys[keyIndex], bytes32(nonce), payload, abi.encodePacked("ILLUMINEX_V1"));
    }

    function _updateRingKey(bytes32 _entropy) private {
        bytes32 newKey = bytes32(Sapphire.randomBytes(32, abi.encodePacked(_entropy)));

        uint newIndex = _ringKeys.length;
        _ringKeys.push(newKey);

        _lastRingKeyUpdate = block.timestamp;
    }

    function _computeNonce(uint256 keyIndex) private pure returns (bytes32 nonce) {
        nonce = keccak256(abi.encodePacked(keyIndex, "ILLUMINEX_V1"));
    }

    function _handleProxyPass(bytes memory _data, uint256 _totalAmount, address _token, uint256 fee) internal virtual returns (bool) {
        (bytes memory header, bytes[] memory entries) = abi.decode(_data, (bytes, bytes[]));
        encryptPayload(abi.encode(msg.sender, entries));
        return true;
    }
}