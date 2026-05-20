// SPDX-License-Identifier: MIT
pragma solidity >=0.8.4;

/// @title ICredential
/// @author Naba Finance
/// @notice Public, dependency-free interface to the UAE Pass `Credential` contract.
///         Integrators use this to gate functionality on UAE Pass provenance —
///         i.e. "was this address created by an official UAE Pass account factory".
///
/// @dev    The canonical predicate is {wasCreatedByUAEPass}. It is a pure
///         provenance check: it returns true iff `account` was deployed through
///         one of the currently trusted UAE Pass account factories. It does NOT
///         attest to real-time control, KYC status, or that any particular
///         validator is still installed on the account.
///
///         Deployed at the same address on every supported chain (CREATE2
///         same-address scheme). See deployments/addresses.json / the README.
///
///         Ownership/admin functions (owner, transferOwnership, acceptOwnership)
///         come from OpenZeppelin's Ownable2Step and are intentionally omitted
///         here; integrators only need the read surface below.
interface ICredential {
    /// @notice Emitted when a factory is added to the trusted list.
    /// @param factory The factory address that was trusted.
    /// @param by      The owner account that performed the change.
    event FactoryAdded(address indexed factory, address indexed by);

    /// @notice Emitted when a factory is removed from the trusted list.
    /// @param factory The factory address that was untrusted.
    /// @param by      The owner account that performed the change.
    event FactoryRemoved(address indexed factory, address indexed by);

    /// @notice Address of the UAE Pass validator associated with this contract.
    /// @dev    This is the `UAEPassValidator` — an ERC-7579 validator module
    ///         installed as the root validator on the ZeroDev Kernel (v3.1)
    ///         accounts that UAE Pass deploys. Returned as a plain `address`;
    ///         cast it to the validator's own interface if you need to call it.
    ///         Informational: {wasCreatedByUAEPass} is a factory-provenance
    ///         check and does NOT depend on this validator still being at root.
    /// @return The validator module address (immutable, same on every chain).
    function validator() external view returns (address);

    /// @notice Whether `factory` is currently in the trusted list.
    /// @param factory The factory address to query.
    /// @return True if the factory is trusted.
    function isTrustedFactory(address factory) external view returns (bool);

    /// @notice The full list of currently trusted factories.
    /// @return The trusted factory addresses.
    function getFactories() external view returns (address[] memory);

    /// @notice Number of trusted factories (for paginated reads).
    /// @return The count of trusted factories.
    function factoriesLength() external view returns (uint256);

    /// @notice Whether `account` was created through a currently trusted UAE
    ///         Pass account factory.
    /// @dev    Provenance check only — see the interface-level notes. Returns
    ///         false for any address not deployed by a trusted factory.
    /// @param account The address to check.
    /// @return True if the account is of UAE Pass provenance.
    function wasCreatedByUAEPass(address account) external view returns (bool);
}
