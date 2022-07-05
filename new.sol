// contracts/MyNFT.sol

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.11;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Pausable.sol";

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Burnable.sol";

import "@openzeppelin/contracts/access/Ownable.sol";

import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";

contract MyNFT is
    ERC721,
    Ownable,
    ERC721Pausable,
    ERC721Burnable,
    ERC721URIStorage
{
    using Strings for uint256;

    using EnumerableSet for EnumerableSet.UintSet;

    mapping(address => EnumerableSet.UintSet) private holderTokens;

    mapping(uint256 => uint256) public price;

    string private baseURI_;

    event BuyNFT(address _buyer, uint256 _tokenId, uint256 _price);

    event SellNFT(address _seller, uint256 _tokenId, uint256 _price);

    event ClaimByOwner(uint256 _price);

    constructor(string memory _baseTokenURI) ERC721("MyNFT", "MNFT") {
        _setBaseURI(_baseTokenURI);
    }

    receive() external payable {}

    fallback() external payable {}

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

    function _burn(uint256 tokenId)
        internal
        override(ERC721, ERC721URIStorage)
    {
        super._burn(tokenId);
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal override(ERC721, ERC721Pausable) {
        super._beforeTokenTransfer(from, to, tokenId);
    }

    function _setBaseURI(string memory _baseTokenURI) internal {
        baseURI_ = _baseTokenURI;
    }

    function _baseURI() internal view override returns (string memory) {
        return baseURI_;
    }

    function tokenURI(uint256 tokenId)
        public
        view
        override(ERC721, ERC721URIStorage)
        returns (string memory)
    {
        require(_exists(tokenId), "MyNFT: URI query for nonexistent token");

        string memory baseURI = _baseURI();

        return
            bytes(baseURI).length > 0
                ? string(abi.encodePacked(baseURI, tokenId.toString()))
                : "";
    }

    function mint(uint256 _tokenId, uint256 _price)
        public
        onlyOwner
        whenNotPaused
    {
        require(!_exists(_tokenId), "MyNFT: Token for this Id already exist");

        _safeMint(_msgSender(), _tokenId);

        holderTokens[_msgSender()].add(_tokenId);

        price[_tokenId] = _price;
    }

    function setPrice(uint256 _tokenId, uint256 _price)
        public
        onlyOwner
        whenNotPaused
    {
        require(
            _price != price[_tokenId],
            "MyNFT: Same price already set for this token Id"
        );

        price[_tokenId] = _price;
    }

    function burn(uint256 _tokenId) public override onlyOwner whenNotPaused {
        require(
            _isApprovedOrOwner(_msgSender(), _tokenId),
            "MyNFT: burn caller is not owner nor approved"
        );

        _burn(_tokenId);

        holderTokens[_msgSender()].remove(_tokenId);

        delete price[_tokenId];
    }

    function pause() public onlyOwner whenNotPaused {
        _pause();
    }

    function unpause() public onlyOwner whenPaused {
        _unpause();
    }

    function getTokens(address _address)
        external
        view
        returns (uint256[] memory)
    {
        return holderTokens[_address].values();
    }

    function buyNFT(uint256 _tokenId) public payable whenNotPaused {
        require(_exists(_tokenId), "MyNFT: Token for this Id doesn't exist");

        require(
            msg.value >= price[_tokenId],
            "MyNFT: Price you are trying to pay isn't sufficient to buy this NFT"
        );

        holderTokens[owner()].remove(_tokenId);

        holderTokens[_msgSender()].add(_tokenId);

        safeTransferFrom(owner(), _msgSender(), _tokenId);

        emit BuyNFT(_msgSender(), _tokenId, price[_tokenId]);
    }

    function sellNFT(uint256 _tokenId) public payable whenNotPaused {
        require(_exists(_tokenId), "MyNFT: Token for this Id doesn't exist");

        holderTokens[_msgSender()].remove(_tokenId);

        holderTokens[owner()].add(_tokenId);

        safeTransferFrom(_msgSender(), owner(), _tokenId);

        _safeTransferEth(_msgSender(), price[_tokenId]);

        emit SellNFT(_msgSender(), _tokenId, price[_tokenId]);
    }

    function fromContractToOwner(uint256 _amount)
        external
        onlyOwner
        whenNotPaused
    {
        require(
            address(this).balance >= _amount,
            "NFT: Not enough balance in the contract"
        );

        _safeTransferEth(owner(), _amount);

        emit ClaimByOwner(_amount);
    }

    function _safeTransferEth(address to, uint256 value)
        internal
        returns (bool)
    {
        (bool success, ) = to.call{value: value}(new bytes(0));

        return success;
    }
}
