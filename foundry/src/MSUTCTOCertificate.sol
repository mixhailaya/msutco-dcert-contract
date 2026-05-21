// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
import "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import "openzeppelin-contracts/contracts/access/Ownable.sol";
import "openzeppelin-contracts/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "openzeppelin-contracts/contracts/utils/Pausable.sol";

/**
 * @title MSUTCTOCertificate
 * @dev A certificate management system for MSU TCTO training certificates
 * Stores certificate metadata on-chain for verification
 */
contract MSUTCTOCertificate is ERC20, ERC20Burnable, Ownable, Pausable {
    
    // Certificate structure
    struct Certificate {
        string certificateId;
        address recipientAddress;
        string recipientName;
        string courseName;
        uint256 completionDate;
        bool isRevoked;
        uint256 issuedAt;
    }

    // Mapping of certificate ID to certificate data
    mapping(string => Certificate) public certificates;
    
    // Mapping to track all certificate IDs
    string[] public certificateIds;
    
    // Mapping of certificate ID to index in certificateIds array
    mapping(string => uint256) public certificateIndex;
    
    // Authorized issuers
    mapping(address => bool) public authorizedIssuers;
    
    // Events
    event CertificateIssued(
        string indexed certificateId,
        address indexed recipientAddress,
        string recipientName,
        string courseName,
        uint256 completionDate,
        uint256 timestamp
    );

    event CertificateRevoked(
        string indexed certificateId,
        uint256 timestamp
    );

    event IssuerAuthorized(address indexed issuer);
    event IssuerRemoved(address indexed issuer);

    // Modifier for authorized issuers only
    modifier onlyAuthorizedIssuer() {
        require(
            authorizedIssuers[msg.sender] || msg.sender == owner(),
            "Not authorized to issue certificates"
        );
        _;
    }

    /**
     * @dev Constructor initializes the contract
     */
    constructor()
        ERC20("MSU TCTO Certificate", "CERT")
        Ownable(msg.sender)
    {}

    // ============ Issuer Management ============

    /**
     * @dev Authorize an address to issue certificates
     * @param issuer Address to authorize
     */
    function authorizeIssuer(address issuer) external onlyOwner {
        require(issuer != address(0), "Invalid address");
        require(!authorizedIssuers[issuer], "Already authorized");
        authorizedIssuers[issuer] = true;
        emit IssuerAuthorized(issuer);
    }

    /**
     * @dev Remove authorization from an issuer
     * @param issuer Address to remove
     */
    function removeIssuer(address issuer) external onlyOwner {
        require(authorizedIssuers[issuer], "Not authorized");
        authorizedIssuers[issuer] = false;
        emit IssuerRemoved(issuer);
    }

    /**
     * @dev Check if an address is authorized to issue
     * @param issuer Address to check
     */
    function isAuthorizedIssuer(address issuer) external view returns (bool) {
        return authorizedIssuers[issuer] || issuer == owner();
    }

    // ============ Certificate Issuance ============

    /**
     * @dev Issue a single certificate
     * @param certificateId Unique certificate ID
     * @param recipientAddress Address of the certificate holder
     * @param recipientName Name of the certificate recipient
     * @param courseName Name of the course
     * @param completionDate Date of completion (timestamp)
     */
    function issueCertificate(
        string memory certificateId,
        address recipientAddress,
        string memory recipientName,
        string memory courseName,
        uint256 completionDate
    ) external onlyAuthorizedIssuer {
        require(recipientAddress != address(0), "Invalid recipient address");
        require(bytes(certificateId).length > 0, "Certificate ID required");
        require(bytes(recipientName).length > 0, "Recipient name required");
        require(bytes(courseName).length > 0, "Course name required");
        require(
            certificates[certificateId].issuedAt == 0,
            "Certificate already exists"
        );

        // Create certificate
        certificates[certificateId] = Certificate({
            certificateId: certificateId,
            recipientAddress: recipientAddress,
            recipientName: recipientName,
            courseName: courseName,
            completionDate: completionDate,
            isRevoked: false,
            issuedAt: block.timestamp
        });

        // Track certificate ID
        certificateIndex[certificateId] = certificateIds.length;
        certificateIds.push(certificateId);

        // Mint a token to recipient
        _mint(recipientAddress, 1 ether);

        emit CertificateIssued(
            certificateId,
            recipientAddress,
            recipientName,
            courseName,
            completionDate,
            block.timestamp
        );
    }

    /**
     * @dev Issue multiple certificates in a batch
     * @param data Array of certificate data
     */
    function issueCertificateBatch(
        CertificateBatchData[] calldata data
    ) external onlyAuthorizedIssuer {
        require(data.length > 0, "No certificates provided");
        require(data.length <= 100, "Batch too large");

        for (uint256 i = 0; i < data.length; i++) {
            CertificateBatchData calldata item = data[i];
            
            require(item.recipientAddress != address(0), "Invalid recipient");
            require(bytes(item.certificateId).length > 0, "Certificate ID required");
            require(bytes(item.recipientName).length > 0, "Recipient name required");
            require(bytes(item.courseName).length > 0, "Course name required");
            require(
                certificates[item.certificateId].issuedAt == 0,
                "Certificate already exists"
            );

            // Create certificate
            certificates[item.certificateId] = Certificate({
                certificateId: item.certificateId,
                recipientAddress: item.recipientAddress,
                recipientName: item.recipientName,
                courseName: item.courseName,
                completionDate: item.completionDate,
                isRevoked: false,
                issuedAt: block.timestamp
            });

            // Track certificate ID
            certificateIndex[item.certificateId] = certificateIds.length;
            certificateIds.push(item.certificateId);

            // Mint a token to recipient
            _mint(item.recipientAddress, 1 ether);

            emit CertificateIssued(
                item.certificateId,
                item.recipientAddress,
                item.recipientName,
                item.courseName,
                item.completionDate,
                block.timestamp
            );
        }
    }

    // ============ Certificate Verification ============

    /**
     * @dev Verify if a certificate exists and is valid
     * @param certificateId The certificate ID to verify
     */
    function verifyCertificate(
        string memory certificateId
    ) external view returns (
        bool exists,
        bool isValid,
        Certificate memory certificate
    ) {
        Certificate storage cert = certificates[certificateId];
        
        exists = cert.issuedAt != 0;
        isValid = exists && !cert.isRevoked;
        certificate = cert;
    }

    /**
     * @dev Get certificate details
     * @param certificateId The certificate ID
     */
    function getCertificate(string memory certificateId)
        external
        view
        returns (Certificate memory)
    {
        require(certificates[certificateId].issuedAt != 0, "Certificate not found");
        return certificates[certificateId];
    }

    /**
     * @dev Check if a certificate is valid (exists and not revoked)
     * @param certificateId The certificate ID
     */
    function isCertificateValid(string memory certificateId)
        external
        view
        returns (bool)
    {
        Certificate storage cert = certificates[certificateId];
        return cert.issuedAt != 0 && !cert.isRevoked;
    }

    /**
     * @dev Check if a certificate is revoked
     * @param certificateId The certificate ID
     */
    function isCertificateRevoked(string memory certificateId)
        external
        view
        returns (bool)
    {
        return certificates[certificateId].isRevoked;
    }

    // ============ Certificate Revocation ============

    /**
     * @dev Revoke a certificate
     * @param certificateId The certificate ID to revoke
     */
    function revokeCertificate(string memory certificateId)
        external
        onlyAuthorizedIssuer
    {
        require(
            certificates[certificateId].issuedAt != 0,
            "Certificate not found"
        );
        require(!certificates[certificateId].isRevoked, "Already revoked");

        certificates[certificateId].isRevoked = true;

        emit CertificateRevoked(certificateId, block.timestamp);
    }

    // ============ Utility Functions ============

    /**
     * @dev Get total number of certificates issued
     */
    function getCertificateCount() external view returns (uint256) {
        return certificateIds.length;
    }

    /**
     * @dev Get certificate IDs by index range (for pagination)
     * @param start Starting index
     * @param limit Number of certificates to return
     */
    function getCertificatesByRange(uint256 start, uint256 limit)
        external
        view
        returns (Certificate[] memory)
    {
        require(start < certificateIds.length, "Invalid start index");
        
        uint256 end = start + limit;
        if (end > certificateIds.length) {
            end = certificateIds.length;
        }

        Certificate[] memory results = new Certificate[](end - start);
        
        for (uint256 i = start; i < end; i++) {
            results[i - start] = certificates[certificateIds[i]];
        }

        return results;
    }

    /**
     * @dev Get all certificate IDs
     */
    function getAllCertificateIds() external view returns (string[] memory) {
        return certificateIds;
    }

    /**
     * @dev Get recent certificates
     * @param count Number of recent certificates to return
     */
    function getRecentCertificates(uint256 count)
        external
        view
        returns (Certificate[] memory)
    {
        uint256 total = certificateIds.length;
        uint256 start = total > count ? total - count : 0;
        
        Certificate[] memory results = new Certificate[](total - start);
        
        for (uint256 i = start; i < total; i++) {
            results[i - start] = certificates[certificateIds[i]];
        }

        return results;
    }

    // ============ Pausable Functions ============

    /**
     * @dev Pause the contract (admin only)
     */
    function pause() external onlyOwner {
        _pause();
    }

    /**
     * @dev Unpause the contract (admin only)
     */
    function unpause() external onlyOwner {
        _unpause();
    }

    // ============ ERC20 Overrides ============

    /**
     * @dev Override _update to respect pause
     */
    function _update(
        address from,
        address to,
        uint256 value
    ) internal override(ERC20) whenNotPaused {
        super._update(from, to, value);
    }

    // ============ Struct Definitions ============

    /**
     * @dev Batch certificate data structure
     */
    struct CertificateBatchData {
        string certificateId;
        address recipientAddress;
        string recipientName;
        string courseName;
        uint256 completionDate;
    }
}
