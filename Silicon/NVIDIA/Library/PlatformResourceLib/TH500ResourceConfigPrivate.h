/** @file
*
*  Copyright (c) 2019-2022, NVIDIA CORPORATION. All rights reserved.
*
*  SPDX-License-Identifier: BSD-2-Clause-Patent
*
**/

#ifndef __TH500_RESOURCE_CONFIG_PRIVATE_H__
#define __TH500_RESOURCE_CONFIG_PRIVATE_H__

#include <Uefi/UefiBaseType.h>
#include <TH500/TH500Definitions.h>

// NOTE The register map would change
#define TEGRA_UART_SUPPORT_FLAG  0x6        // UART_0..1

#define MAX_RETIRED_DRAM_PAGES  1024

#define TEGRA_UART_ADDRESS_0  0x0c280000
#define TEGRA_UART_ADDRESS_1  0x03100000

#define CARVEOUT_NONE                     0
#define CARVEOUT_EGM                      1
#define CARVEOUT_BPMP_CPUTZ               2
#define CARVEOUT_BPMP_CPU_NS              3
#define CARVEOUT_CCPLEX_INTERWORLD_SHMEM  4
#define CARVEOUT_MB2_PARAMS               5
#define CARVEOUT_BPMP                     6
#define CARVEOUT_BPMP_PSC                 7
#define CARVEOUT_PSC_TZ                   8
#define CARVEOUT_PSC                      9
#define CARVEOUT_ETR                      10
#define CARVEOUT_UNUSED_GSC11             11
#define CARVEOUT_UNUSED_GSC12             12
#define CARVEOUT_UNUSED_GSC13             13
#define CARVEOUT_MCE_USB_CTRL             14
#define CARVEOUT_UNUSED_GSC15             15
#define CARVEOUT_UNUSED_GSC16             16
#define CARVEOUT_UNUSED_GSC17             17
#define CARVEOUT_UNUSED_GSC18             18
#define CARVEOUT_UNUSED_GSC19             19
#define CARVEOUT_UNUSED_GSC20             20
#define CARVEOUT_UNUSED_GSC21             21
#define CARVEOUT_UNUSED_GSC22             22
#define CARVEOUT_UNUSED_GSC23             23
#define CARVEOUT_UNUSED_GSC24             24
#define CARVEOUT_UNUSED_GSC25             25
#define CARVEOUT_UNUSED_GSC26             26
#define CARVEOUT_UNUSED_GSC27             27
#define CARVEOUT_UNUSED_GSC28             28
#define CARVEOUT_UNUSED_GSC29             29
#define CARVEOUT_UNUSED_GSC30             30
#define CARVEOUT_UNUSED_GSC31             31
#define CARVEOUT_UNUSED_GSC_LITE32        32
#define CARVEOUT_MTS                      33
#define CARVEOUT_TZDRAM                   34

#define CARVEOUT_PROFILING          35
#define CARVEOUT_RCM_BLOB           36
#define CARVEOUT_UEFI               37
#define CARVEOUT_CCPLEX_LA_BUFFERS  38
#define CARVEOUT_OS                 39
#define CARVEOUT_RSVD1              40
#define CARVEOUT_RSVD2              41
#define CARVEOUT_RSVD3              42
#define CARVEOUT_RSVD4              43
#define CARVEOUT_RSVD5              44
#define CARVEOUT_RSVD6              45
#define CARVEOUT_RSVD7              46
#define CARVEOUT_RSVD8              47
#define CARVEOUT_RSVD9              48
#define CARVEOUT_RSVD10             49
#define CARVEOUT_RSVD11             50
#define CARVEOUT_OEM_COUNT          51

typedef struct {
  UINT64    Base;
  UINT64    Size;
  union {
    struct {
      UINT64    EccProtected : 1;
      UINT64    Reserved     : 63;
    };

    UINT64    Flags;
  };
} TEGRABL_CARVEOUT_INFO;

#define TEGRABL_MAX_CONTROLLER_PROD_WORDS  64

#pragma pack(1)
typedef struct  {
  UINT32    NumWords;
  UINT32    Reserved;
  UINT32    Data[TEGRABL_MAX_CONTROLLER_PROD_WORDS];
} TEGRABL_CONTROLLER_PROD_DATA;

#pragma pack(1)
typedef struct  {
  UINT64    Base;
  UINT64    Size;
} TEGRABL_SDRAM_INFO_DATA;

#pragma pack()
typedef struct {
  /**< version */
  UEFI_DECLARE_ALIGNED (UINT32 Version, 4);

  /**< Uart instance */
  UEFI_DECLARE_ALIGNED (UINT32 Uart_Instance, 4);

  /**< EEPROM data */
  UEFI_DECLARE_ALIGNED (TEGRABL_EEPROM_DATA Eeprom, 8);

  /**< List of physical addresses of retired pages */
  UEFI_DECLARE_ALIGNED (UINT64 RetiredDramPages[TH500_MAX_SOCKETS][MAX_RETIRED_DRAM_PAGES], 8);

  /**< Controller prod data */
  UEFI_DECLARE_ALIGNED (TEGRABL_CONTROLLER_PROD_DATA ControllerProdSetting, 8);

  /**< Bit mask to specify which sockets are enabled */
  UEFI_DECLARE_ALIGNED (UINT32 SocketMask, 8);

  /**
    * Bit map of enabled cores.
    * There are 76 cores per socket. A bit is set when corresponding core is enabled
    * otherwise core is either disabled or not available for use.
    **/
  UEFI_DECLARE_ALIGNED (UINT64 EnabledCores[TH500_MAX_SOCKETS][2], 8);

  /**< Base and size information of the DRAM connected to each socket */
  UEFI_DECLARE_ALIGNED (TEGRABL_SDRAM_INFO_DATA SdramInfo[TH500_MAX_SOCKETS], 8);

  /**
   * physical address and size of the carveouts allocated on each socket.
   * If carveout is not allocated on a particular socket then base and size
   * would be set to zero.
   */
  UEFI_DECLARE_ALIGNED (TEGRABL_CARVEOUT_INFO CarveoutInfo[TH500_MAX_SOCKETS][CARVEOUT_OEM_COUNT], 8);

  /**< Feature flags */
  UEFI_DECLARE_ALIGNED (
    struct {
    union {
      UINT64 FeatureFlagRaw1;
      struct {
        /**
         * Boot chain selection mode
         * 0: BCT Marker Mode
         * 1: GPIO Mode
         */
        UINT64 BootChainSelectionMode: 1;
        UINT64 FeatureFlagRaw1Reserved: 63;
      };
    };

    UINT64 FeatureFlagRaw2;
  },
    8
    );

  /**
   * Uphy link checksum status bit mask from each socket.
   * There are 6 uphy controllers per socket. A bit is set when
   * checksum verification is failed for corresponding uphy controller,
   * otherwise checksum verification is passed.
   */
  UEFI_DECLARE_ALIGNED (UINT8 UphyLinkChecksumStatusp[TH500_MAX_SOCKETS], 8);
} TEGRA_CPUBL_PARAMS;

#endif //__TH500_RESOURCE_CONFIG_PRIVATE_H__