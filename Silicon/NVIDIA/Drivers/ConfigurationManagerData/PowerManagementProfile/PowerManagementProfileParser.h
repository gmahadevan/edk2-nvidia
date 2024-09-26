/** @file
  Power management profile parser.

  SPDX-FileCopyrightText: Copyright (c) 2023-2024 NVIDIA CORPORATION & AFFILIATES. All rights reserved.

  SPDX-License-Identifier: BSD-2-Clause-Patent
**/

#ifndef POWER_MANAGEMENT_PROFILE_PARSER_H_
#define POWER_MANAGEMENT_PROFILE_PARSER_H_

#include <Library/NvCmObjectDescUtility.h>

/** Power management profile parser function.

  The following structure is populated:
  typedef struct CmArmPowerManagementProfileInfo {
    // This is the Preferred_PM_Profile field of the FADT Table
    // described in the ACPI Specification
    UINT8    PowerManagementProfile;      // {Populated}
  } CM_ARCH_COMMON_POWER_MANAGEMENT_PROFILE_INFO;

  A parser parses a Device Tree to populate a specific CmObj type. None,
  one or many CmObj can be created by the parser.
  The created CmObj are then handed to the parser's caller through the
  HW_INFO_ADD_OBJECT interface.
  This can also be a dispatcher. I.e. a function that not parsing a
  Device Tree but calling other parsers.

  @param [in]  ParserHandle    A handle to the parser instance.
  @param [in]  FdtBranch       When searching for DT node name, restrict
                               the search to this Device Tree branch.

  @retval EFI_SUCCESS             The function completed successfully.
  @retval EFI_ABORTED             An error occurred.
  @retval EFI_INVALID_PARAMETER   Invalid parameter.
  @retval EFI_NOT_FOUND           Not found.
  @retval EFI_UNSUPPORTED         Unsupported.
**/
EFI_STATUS
EFIAPI
PowerManagementProfileParser (
  IN  CONST HW_INFO_PARSER_HANDLE  ParserHandle,
  IN        INT32                  FdtBranch
  );

#endif // POWER_MANAGEMENT_PROFILE_PARSER_H_
