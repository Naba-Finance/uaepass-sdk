// SPDX-License-Identifier: MIT
pragma solidity >=0.8.4;

/// @title ICredential
/// @author Naba Finance
/// @notice Public, dependency-free interface to the UAE Pass `Credential` contract.
///         Integrators use this to gate functionality on UAE Pass provenance —
///         i.e. "was this address created by an official UAE Pass account factory
///         and authorised at least once through UAE Pass".
///
/// @dev    The canonical predicate is {wasCreatedByUAEPass}. It is a provenance
///         check: it returns true iff, for at least one currently trusted
///         factory, `account` was deployed by that factory AND
///         `EntryPoint.getNonce(account, 0) > 0`, i.e. the account has executed
///         at least one UserOperation through its root validator (the UAE Pass
///         validator). Deployment alone is not enough, because account creation
///         is permissionless and accepts any identity commitment.
///
///         Consequences for integrators:
///         - An account becomes eligible during its first UserOperation
///           (the EntryPoint increments the nonce before execution), and not
///           before. A freshly deployed account that has not yet sent a
///           UserOperation is NOT eligible.
///         - Eligibility is monotonic while the factory stays trusted: the
///           nonce never decreases.
///         - Accounts that only ever use a non-zero nonce key stay ineligible
///           (false negatives are possible, false positives are not).
///         - Do NOT call it from ERC-4337 validation code (validateUserOp,
///           paymaster validation): it reads EntryPoint and factory storage,
///           which ERC-7562 forbids there. Call it from execution only.
///
///         It does NOT attest to real-time control, KYC status, or that any
///         particular validator is still installed on the account.
///
///         The trusted factory list contains the `FactoryAdapter`, which wraps
///         the `AccountFactory` and adds the nonce check. The raw
///         `AccountFactory` is the deployment entry point but is not itself
///         trusted; do not query its `deployedByThisFactory` as a substitute.
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
    ///         Pass account factory and has executed at least one UserOperation.
    /// @dev    Provenance check only — see the interface-level notes. Returns
    ///         false for any address not deployed by a trusted factory, and for
    ///         a deployed account whose `EntryPoint.getNonce(account, 0)` is 0.
    ///         Not callable during ERC-4337 validation (ERC-7562).
    /// @param account The address to check.
    /// @return True if the account is of UAE Pass provenance.
    function wasCreatedByUAEPass(address account) external view returns (bool);
}
