package abi29_0_0.host.exp.exponent;

import java.util.List;

import abi29_0_0.expo.core.interfaces.Package;
import abi29_0_0.host.exp.exponent.modules.universal.ExpoModuleRegistryAdapter;

public interface ExponentPackageDelegate {
  ExpoModuleRegistryAdapter getScopedModuleRegistryAdapterForPackages(List<Package> packages);
}
