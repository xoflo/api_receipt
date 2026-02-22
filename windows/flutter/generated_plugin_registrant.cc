//
//  Generated file. Do not edit.
//

// clang-format off

#include "generated_plugin_registrant.h"

#include <print_bluetooth_thermal/print_bluetooth_thermal_plugin_c_api.h>
#include <thermal_printer/thermal_printer_plugin.h>

void RegisterPlugins(flutter::PluginRegistry* registry) {
  PrintBluetoothThermalPluginCApiRegisterWithRegistrar(
      registry->GetRegistrarForPlugin("PrintBluetoothThermalPluginCApi"));
  ThermalPrinterPluginRegisterWithRegistrar(
      registry->GetRegistrarForPlugin("ThermalPrinterPlugin"));
}
