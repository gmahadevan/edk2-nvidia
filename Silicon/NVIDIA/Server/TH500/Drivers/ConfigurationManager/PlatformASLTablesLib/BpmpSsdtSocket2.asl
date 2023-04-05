/** @file
  SSDT for TH500 Socket 2 devices

  Copyright (c) 2022 - 2023, NVIDIA Corporation. All rights reserved.

  SPDX-License-Identifier: BSD-2-Clause-Patent

  Template for [SSDT] ACPI Table (AML byte code table)
**/

#include <TH500/TH500Definitions.h>
#include <Protocol/BpmpIpc.h>
#include <AcpiPowerMeter.h>

DefinitionBlock ("BpmpSsdtSocket2.aml", "SSDT", 2, "NVIDIA", "BPMP_S2", 0x00000001)
{
  Scope(_SB) {
    //---------------------------------------------------------------------
    // BPMP Device
    //---------------------------------------------------------------------

    Device (BPM2)
    {
      Name (_HID, EISAID("PNP0C02")) // Motherboard resources
      Name (_UID, "BPMP IPC Socket 2")
      Name (PSVT, (TH500_THERMAL_ZONE_PSV + 2732))
      Name (CRTT, (TH500_THERMAL_ZONE_CRT + 2732))
      Name (TC1T, TH500_THERMAL_ZONE_TC1)
      Name (TC2T, TH500_THERMAL_ZONE_TC2)
      Name (TBUF, 0xFFFFFFFFFFFFFFFF)
      Name (TIME, 0xFF)
      Name (LSTM, 0)
      Name (PWRV, 0x00000000)

      OperationRegion (BPTX, SystemMemory, BPMP_TX_MAILBOX_SOCKET_2, BPMP_CHANNEL_SIZE)
      Field (BPTX, AnyAcc, NoLock, Preserve) {
        TWCT, 32,
        TSTA, 32,
        Offset (64),
        TRCT, 32,
        Offset (128),
        TMRQ, 32,
        TFLA, 32,
        TDAT, 960
      }

      OperationRegion (BPRX, SystemMemory, BPMP_RX_MAILBOX_SOCKET_2, BPMP_CHANNEL_SIZE)
      Field (BPRX, AnyAcc, NoLock, Preserve) {
        RWCT, 32,
        RSTA, 32,
        Offset (64),
        RRCT, 32,
        Offset (128),
        RERR, 32,
        RFLG, 32,
        RDAT, 960
      }

      Method (BIPC, 2, Serialized, 0, PkgObj, {IntObj, BuffObj}) {
        OperationRegion (DRBL, SystemMemory, BPMP_DOORBELL_SOCKET_2, BPMP_DOORBELL_SIZE)
        Field (DRBL, AnyAcc, NoLock, Preserve) {
          TRIG, 4,
          ENA,  4,
          RAW,  4,
          PEND, 4
        }

        TMRQ = Arg0
        TFLA = One
        TDAT = Arg1
        Increment (TWCT)
        Store (One, TRIG)

        While (RWCT == RRCT) {
          Sleep (10)
        }
        Increment (RRCT)
        Return (Package() {RERR, RDAT})
      }

      Method (TEMP, 1, Serialized, 0, IntObj, IntObj) {
        Local0 = Buffer(8){}
        CreateDWordField (Local0, 0x00, CMD)
        CreateDWordField (Local0, 0x04, ZONE)
        CMD = ZONE_TEMP
        ZONE = Arg0
        Local1 = \_SB.BPM2.BIPC (MRQ_THERMAL, Local0)
        CreateDWordField (DerefOf (Index (Local1, 0)), 0x00, ERR)
        if (ERR != 0) {
          Return (2732)
        }
        CreateDWordField (DerefOf (Index (Local1, 1)), 0x00, TEMP)
        Local3 = TEMP / 100
        Local4 = 2732
        Add (Local3, Local4, Local3)
        Return (Local3)
      }

      Method (TELM, 2, Serialized, 0, IntObj, {IntObj, IntObj}) {
        Local0 = 0
        Local1 = 0
        Local2 = TH500_BPMP_IPC_CALL_INTERVAL_50MS
        Local3 = 0
        Local4 = 0
        Local5 = 0

        If ((Arg0 < TH500_MODULE_PWR) || (Arg0 > TH500_SOC_PWR)) {
          Return (PWR_METER_ERR_RETURN)
        }

        If ((Arg1 != PWR_METER_MEASUREMENT_SAMPLING_TIME_50MS) && (Arg1 != PWR_METER_MEASUREMENT_SAMPLING_TIME_1SEC)) {
          Return (PWR_METER_ERR_RETURN)
        }

        If (TIME != 0) {
          If (LSTM > Timer()) {
            Store(Timer(), LSTM)
          }
          Add (LSTM, Local2, Local3)
          If (LGreater (Timer(), Local3)) {
            Local4 = 1
          } Else {
            Local4 = 0
          }
        }

        If (LOr((TIME == 0), Local4)) {
          Local1 = \_SB.BPM2.BIPC (MRQ_TELEMETRY, Local0)
          CreateDWordField (DerefOf (Index (Local1, 0)), 0x00, ERR)
          If (ERR != 0) {
            Return (PWR_METER_ERR_RETURN)
          }
          CreateQWordField (DerefOf (Index (Local1, 1)), 0x00, BUFF)

          OperationRegion (TELD, SystemMemory, BUFF, 0x180)
          Field (TELD, AnyAcc, NoLock, Preserve) {
            Offset (16),
            MPWR, 32,
            TPWR, 32,
            CPWR, 32,
            SPWR, 32,
            Offset (288),
            MAPW, 32,
            TAPW, 32,
            CAPW, 32,
            SAPW, 32,
            Offset (360),
            VFG0, 32,
            VFG1, 32,
            VFG2, 32
          }

          Switch (Arg0) {
            Case (TH500_MODULE_PWR) {
              If (Arg1 == PWR_METER_MEASUREMENT_SAMPLING_TIME_50MS) {
                And (VFG0, TH500_MODULE_PWR_IDX_VALID_FLAG, Local5)
                If (Local5 > 0) {
                  Store (MPWR, PWRV)
                }
              }
              If (Arg1 == PWR_METER_MEASUREMENT_SAMPLING_TIME_1SEC) {
                And (VFG2, TH500_MODULE_PWR_1SEC_IDX_VALID_FLAG, Local5)
                If (Local5 > 0) {
                  Store (MAPW, PWRV)
                }
              }
              Break
            }

            Case (TH500_TH500_PWR) {
              If (Arg1 == PWR_METER_MEASUREMENT_SAMPLING_TIME_50MS) {
                And (VFG0, TH500_TH500_PWR_IDX_VALID_FLAG, Local5)
                If (Local5 > 0) {
                  Store (TPWR, PWRV)
                }
              }
              If (Arg1 = PWR_METER_MEASUREMENT_SAMPLING_TIME_1SEC) {
                And (VFG2, TH500_TH500_PWR_1SEC_IDX_VALID_FLAG, Local5)
                If (Local5 > 0) {
                  Store (TAPW, PWRV)
                }
              }
              Break
            }

            Case (TH500_CPU_PWR) {
              If (Arg1 == PWR_METER_MEASUREMENT_SAMPLING_TIME_50MS) {
                And (VFG0, TH500_CPU_PWR_IDX_VALID_FLAG, Local5)
                If (Local5 > 0) {
                  Store (CPWR, PWRV)
                }
              }
              If (Arg1 = PWR_METER_MEASUREMENT_SAMPLING_TIME_1SEC) {
                And (VFG2, TH500_CPU_PWR_1SEC_IDX_VALID_FLAG, Local5)
                If (Local5 > 0) {
                  Store (CAPW, PWRV)
                }
              }
              Break
            }

            Case (TH500_SOC_PWR) {
              If (Arg1 == PWR_METER_MEASUREMENT_SAMPLING_TIME_50MS) {
                And (VFG0, TH500_SOC_PWR_IDX_VALID_FLAG, Local5)
                If (Local5 > 0) {
                  Store (SPWR, PWRV)
                }
              }
              If (Arg1 = PWR_METER_MEASUREMENT_SAMPLING_TIME_1SEC) {
                And (VFG2, TH500_SOC_PWR_1SEC_IDX_VALID_FLAG, Local5)
                If (Local5 > 0) {
                  Store (SAPW, PWRV)
                }
              }
              Break
            }
          }

          If (TIME != 0) {
            Store (Timer(), LSTM)
          }
        }
        Return (PWRV)
      }

      Method (SPRL, 2, Serialized, 0, IntObj, {IntObj, IntObj}) {
        Local0 = Buffer (20) {}

        CreateDWordField (Local0, 0x00, CMD)
        CreateDWordField (Local0, 0x04, LIID)
        CreateDWordField (Local0, 0x08, LISR)
        CreateDWordField (Local0, 0x0C, LITY)
        CreateDWordField (Local0, 0x10, LISE)

        CMD = TH500_PWR_LIMIT_SET
        LIID = Arg0
        LISR = TH500_PWR_LIMIT_SRC_INB
        LITY = TH500_PWR_LIMIT_TYPE_TARGET_CAP
        LISE = Arg1

        Local1 = \_SB.BPM2.BIPC (MRQ_PWR_LIMIT, Local0)
        CreateDWordField (DerefOf (Index (Local1, 0)), 0x00, ERR)
        if (ERR != 0) {
          Return (PWR_METER_UNKNOWN_HW_ERR)
        }
        Return (PWR_METER_SUCCESS)
      }

      Method (GPRL, 1, Serialized, 0, IntObj, IntObj) {
        Local0 = Buffer (16) {}

        CreateDWordField (Local0, 0x00, CMD)
        CreateDWordField (Local0, 0x04, LIID)
        CreateDWordField (Local0, 0x08, LISR)
        CreateDWordField (Local0, 0x0C, LITY)

        CMD = TH500_PWR_LIMIT_GET
        LIID = Arg0
        LISR = TH500_PWR_LIMIT_SRC_INB
        LITY = TH500_PWR_LIMIT_TYPE_TARGET_CAP

        Local1 = \_SB.BPM2.BIPC (MRQ_PWR_LIMIT, Local0)
        CreateDWordField (DerefOf (Index (Local1, 0)), 0x00, ERR)
        if (ERR != 0) {
          Return (PWR_METER_ERR_RETURN)
        }
        CreateDWordField (DerefOf (Index (Local1, 1)), 0x00, PLIM)
        Return (PLIM)
      }
    }

    // Socket 2 CPUs 0-83
    External(\_SB.C002.C000)
    External(\_SB.C002.C002)
    External(\_SB.C002.C003)
    External(\_SB.C002.C004)
    External(\_SB.C002.C005)
    External(\_SB.C002.C006)
    External(\_SB.C002.C007)
    External(\_SB.C002.C008)
    External(\_SB.C002.C009)
    External(\_SB.C002.C00A)
    External(\_SB.C002.C00B)
    External(\_SB.C002.C00C)
    External(\_SB.C002.C00E)
    External(\_SB.C002.C010)
    External(\_SB.C002.C011)
    External(\_SB.C002.C012)
    External(\_SB.C002.C013)
    External(\_SB.C002.C014)
    External(\_SB.C002.C015)
    External(\_SB.C002.C016)
    External(\_SB.C002.C017)
    External(\_SB.C002.C018)
    External(\_SB.C002.C019)
    External(\_SB.C002.C01A)
    External(\_SB.C002.C01C)
    External(\_SB.C002.C01D)
    External(\_SB.C002.C01E)
    External(\_SB.C002.C01F)
    External(\_SB.C002.C020)
    External(\_SB.C002.C021)
    External(\_SB.C002.C022)
    External(\_SB.C002.C023)
    External(\_SB.C002.C024)
    External(\_SB.C002.C025)
    External(\_SB.C002.C026)
    External(\_SB.C002.C027)
    External(\_SB.C002.C028)
    External(\_SB.C002.C029)
    External(\_SB.C002.C02A)
    External(\_SB.C002.C02B)
    External(\_SB.C002.C02C)
    External(\_SB.C002.C02D)
    External(\_SB.C002.C02E)
    External(\_SB.C002.C02F)
    External(\_SB.C002.C030)
    External(\_SB.C002.C031)
    External(\_SB.C002.C032)
    External(\_SB.C002.C033)
    External(\_SB.C002.C034)
    External(\_SB.C002.C035)
    External(\_SB.C002.C036)
    External(\_SB.C002.C037)
    External(\_SB.C002.C038)
    External(\_SB.C002.C03A)
    External(\_SB.C002.C03B)
    External(\_SB.C002.C03C)
    External(\_SB.C002.C03D)
    External(\_SB.C002.C03E)
    External(\_SB.C002.C03F)
    External(\_SB.C002.C040)
    External(\_SB.C002.C041)
    External(\_SB.C002.C042)
    External(\_SB.C002.C043)
    External(\_SB.C002.C044)
    External(\_SB.C002.C046)
    External(\_SB.C002.C048)
    External(\_SB.C002.C049)
    External(\_SB.C002.C04A)
    External(\_SB.C002.C04B)
    External(\_SB.C002.C04C)
    External(\_SB.C002.C04D)
    External(\_SB.C002.C04E)
    External(\_SB.C002.C04F)
    External(\_SB.C002.C050)
    External(\_SB.C002.C051)
    External(\_SB.C002.C052)

    // Thermal Zones
    // TZ20 to TZ2F

ThermalZone (TZ20) {
      Method(_TMP) { Return (\_SB.BPM2.TEMP (TH500_THERMAL_ZONE_CPU0) )} // get current temp
      Name(_PSL, Package (){
                            \_SB.C002.C004,
                            \_SB.C002.C002,
                            \_SB.C002.C000,
                            \_SB.C002.C00E }) // passive cooling devices
      Method(_PSV) { Return (\_SB.BPM2.PSVT) }
      Method(_TC1) { Return (\_SB.BPM2.TC1T) }
      Method(_TC2) { Return (\_SB.BPM2.TC2T) }
      Method(_CRT) { Return (\_SB.BPM2.CRTT) }
      Name(_TSP, TH500_THERMAL_ZONE_TSP)
      Name(_TZP, TEMP_POLL_TIME_100MS)
      Name (_STR, Unicode ("Thermal Zone Skt2 CPU0"))
    }

    ThermalZone (TZ21) {
      Method(_TMP) { Return (\_SB.BPM2.TEMP (TH500_THERMAL_ZONE_CPU1) )} // get current temp
      Name(_PSL, Package (){
                            \_SB.C002.C00A,
                            \_SB.C002.C006,
                            \_SB.C002.C008,
                            \_SB.C002.C00C,
                            \_SB.C002.C01A }) // passive cooling devices
      Method(_PSV) { Return (\_SB.BPM2.PSVT) }
      Method(_TC1) { Return (\_SB.BPM2.TC1T) }
      Method(_TC2) { Return (\_SB.BPM2.TC2T) }
      Method(_CRT) { Return (\_SB.BPM2.CRTT) }
      Name(_TSP, TH500_THERMAL_ZONE_TSP)
      Name(_TZP, TEMP_POLL_TIME_100MS)
      Name (_STR, Unicode ("Thermal Zone Skt2 CPU1"))
    }

    ThermalZone (TZ22) {
      Method(_TMP) { Return (\_SB.BPM2.TEMP (TH500_THERMAL_ZONE_CPU2) )} // get current temp
      Name(_PSL, Package (){
                            \_SB.C002.C005,
                            \_SB.C002.C012,
                            \_SB.C002.C013,
                            \_SB.C002.C020,
                            \_SB.C002.C021,
                            \_SB.C002.C01C }) // passive cooling devices
      Method(_PSV) { Return (\_SB.BPM2.PSVT) }
      Method(_TC1) { Return (\_SB.BPM2.TC1T) }
      Method(_TC2) { Return (\_SB.BPM2.TC2T) }
      Method(_CRT) { Return (\_SB.BPM2.CRTT) }
      Name(_TSP, TH500_THERMAL_ZONE_TSP)
      Name(_TZP, TEMP_POLL_TIME_100MS)
      Name (_STR, Unicode ("Thermal Zone Skt2 CPU2"))
    }

    ThermalZone (TZ23) {
      Method(_TMP) { Return (\_SB.BPM2.TEMP (TH500_THERMAL_ZONE_CPU2) )} // get current temp
      Name(_PSL, Package (){
                            \_SB.C002.C01D,
                            \_SB.C002.C003,
                            \_SB.C002.C010,
                            \_SB.C002.C011,
                            \_SB.C002.C01E,
                            \_SB.C002.C01F }) // passive cooling devices
      Method(_PSV) { Return (\_SB.BPM2.PSVT) }
      Method(_TC1) { Return (\_SB.BPM2.TC1T) }
      Method(_TC2) { Return (\_SB.BPM2.TC2T) }
      Method(_CRT) { Return (\_SB.BPM2.CRTT) }
      Name(_TSP, TH500_THERMAL_ZONE_TSP)
      Name(_TZP, TEMP_POLL_TIME_100MS)
      Name (_STR, Unicode ("Thermal Zone Skt2 CPU2"))
    }

    ThermalZone (TZ24) {
      Method(_TMP) { Return (\_SB.BPM2.TEMP (TH500_THERMAL_ZONE_CPU3) )} // get current temp
      Name(_PSL, Package (){
                            \_SB.C002.C007,
                            \_SB.C002.C014,
                            \_SB.C002.C015,
                            \_SB.C002.C022,
                            \_SB.C002.C023,
                            \_SB.C002.C00B,
                            \_SB.C002.C018,
                            \_SB.C002.C019,
                            \_SB.C002.C026 }) // passive cooling devices
      Method(_PSV) { Return (\_SB.BPM2.PSVT) }
      Method(_TC1) { Return (\_SB.BPM2.TC1T) }
      Method(_TC2) { Return (\_SB.BPM2.TC2T) }
      Method(_CRT) { Return (\_SB.BPM2.CRTT) }
      Name(_TSP, TH500_THERMAL_ZONE_TSP)
      Name(_TZP, TEMP_POLL_TIME_100MS)
      Name (_STR, Unicode ("Thermal Zone Skt2 CPU3"))
    }

    ThermalZone (TZ25) {
      Method(_TMP) { Return (\_SB.BPM2.TEMP (TH500_THERMAL_ZONE_CPU3) )} // get current temp
      Name(_PSL, Package (){
                            \_SB.C002.C027,
                            \_SB.C002.C028,
                            \_SB.C002.C029,
                            \_SB.C002.C009,
                            \_SB.C002.C016,
                            \_SB.C002.C017,
                            \_SB.C002.C024,
                            \_SB.C002.C025 }) // passive cooling devices
      Method(_PSV) { Return (\_SB.BPM2.PSVT) }
      Method(_TC1) { Return (\_SB.BPM2.TC1T) }
      Method(_TC2) { Return (\_SB.BPM2.TC2T) }
      Method(_CRT) { Return (\_SB.BPM2.CRTT) }
      Name(_TSP, TH500_THERMAL_ZONE_TSP)
      Name(_TZP, TEMP_POLL_TIME_100MS)
      Name (_STR, Unicode ("Thermal Zone Skt2 CPU3"))
    }

    ThermalZone (TZ26) {
      Method(_TMP) { Return (\_SB.BPM2.TEMP (TH500_THERMAL_ZONE_SOC0) )} // get current temp
      Name(_PSL, Package (){
                            \_SB.C002.C02A,
                            \_SB.C002.C02B,
                            \_SB.C002.C02D,
                            \_SB.C002.C02C,
                            \_SB.C002.C03B,
                            \_SB.C002.C03A }) // passive cooling devices
      Method(_PSV) { Return (\_SB.BPM2.PSVT) }
      Method(_TC1) { Return (\_SB.BPM2.TC1T) }
      Method(_TC2) { Return (\_SB.BPM2.TC2T) }
      Method(_CRT) { Return (\_SB.BPM2.CRTT) }
      Name(_TSP, TH500_THERMAL_ZONE_TSP)
      Name(_TZP, TEMP_POLL_TIME_100MS)
      Name (_STR, Unicode ("Thermal Zone Skt2 SOC0"))
    }

    ThermalZone (TZ27) {
      Method(_TMP) { Return (\_SB.BPM2.TEMP (TH500_THERMAL_ZONE_SOC0) )} // get current temp
      Name(_PSL, Package (){
                            \_SB.C002.C049,
                            \_SB.C002.C02F,
                            \_SB.C002.C02E,
                            \_SB.C002.C03D,
                            \_SB.C002.C03C,
                            \_SB.C002.C04B }) // passive cooling devices
      Method(_PSV) { Return (\_SB.BPM2.PSVT) }
      Method(_TC1) { Return (\_SB.BPM2.TC1T) }
      Method(_TC2) { Return (\_SB.BPM2.TC2T) }
      Method(_CRT) { Return (\_SB.BPM2.CRTT) }
      Name(_TSP, TH500_THERMAL_ZONE_TSP)
      Name(_TZP, TEMP_POLL_TIME_100MS)
      Name (_STR, Unicode ("Thermal Zone Skt2 SOC0"))
    }

    ThermalZone (TZ28) {
      Method(_TMP) { Return (\_SB.BPM2.TEMP (TH500_THERMAL_ZONE_SOC1) )} // get current temp
      Name(_PSL, Package (){
                            \_SB.C002.C031,
                            \_SB.C002.C030,
                            \_SB.C002.C03F,
                            \_SB.C002.C03E,
                            \_SB.C002.C04D,
                            \_SB.C002.C033,
                            \_SB.C002.C032,
                            \_SB.C002.C041,
                            \_SB.C002.C040 }) // passive cooling devices
      Method(_PSV) { Return (\_SB.BPM2.PSVT) }
      Method(_TC1) { Return (\_SB.BPM2.TC1T) }
      Method(_TC2) { Return (\_SB.BPM2.TC2T) }
      Method(_CRT) { Return (\_SB.BPM2.CRTT) }
      Name(_TSP, TH500_THERMAL_ZONE_TSP)
      Name(_TZP, TEMP_POLL_TIME_100MS)
      Name (_STR, Unicode ("Thermal Zone Skt2 SOC1"))
    }

    ThermalZone (TZ29) {
      Method(_TMP) { Return (\_SB.BPM2.TEMP (TH500_THERMAL_ZONE_SOC1) )} // get current temp
      Name(_PSL, Package (){
                            \_SB.C002.C04F,
                            \_SB.C002.C035,
                            \_SB.C002.C034,
                            \_SB.C002.C043,
                            \_SB.C002.C042,
                            \_SB.C002.C051,
                            \_SB.C002.C036,
                            \_SB.C002.C037 }) // passive cooling devices
      Method(_PSV) { Return (\_SB.BPM2.PSVT) }
      Method(_TC1) { Return (\_SB.BPM2.TC1T) }
      Method(_TC2) { Return (\_SB.BPM2.TC2T) }
      Method(_CRT) { Return (\_SB.BPM2.CRTT) }
      Name(_TSP, TH500_THERMAL_ZONE_TSP)
      Name(_TZP, TEMP_POLL_TIME_100MS)
      Name (_STR, Unicode ("Thermal Zone Skt2 SOC1"))
    }

    ThermalZone (TZ2A) {
      Method(_TMP) { Return (\_SB.BPM2.TEMP (TH500_THERMAL_ZONE_SOC2) )} // get current temp
      Name(_PSL, Package (){,
                            \_SB.C002.C048,
                            \_SB.C002.C038,
                            \_SB.C002.C046,
                            \_SB.C002.C04A }) // passive cooling devices
      Method(_PSV) { Return (\_SB.BPM2.PSVT) }
      Method(_TC1) { Return (\_SB.BPM2.TC1T) }
      Method(_TC2) { Return (\_SB.BPM2.TC2T) }
      Method(_CRT) { Return (\_SB.BPM2.CRTT) }
      Name(_TSP, TH500_THERMAL_ZONE_TSP)
      Name(_TZP, TEMP_POLL_TIME_100MS)
      Name (_STR, Unicode ("Thermal Zone Skt2 SOC2"))
    }

    ThermalZone (TZ2B) {
      Method(_TMP) { Return (\_SB.BPM2.TEMP (TH500_THERMAL_ZONE_SOC3) )} // get current temp
      Name(_PSL, Package (){
                            \_SB.C002.C04C,
                            \_SB.C002.C04E,
                            \_SB.C002.C050,
                            \_SB.C002.C044,
                            \_SB.C002.C052 }) // passive cooling devices
      Method(_PSV) { Return (\_SB.BPM2.PSVT) }
      Method(_TC1) { Return (\_SB.BPM2.TC1T) }
      Method(_TC2) { Return (\_SB.BPM2.TC2T) }
      Method(_CRT) { Return (\_SB.BPM2.CRTT) }
      Name(_TSP, TH500_THERMAL_ZONE_TSP)
      Name(_TZP, TEMP_POLL_TIME_100MS)
      Name (_STR, Unicode ("Thermal Zone Skt2 SOC3"))
    }

    ThermalZone (TZ2C) {
      Method(_TMP) { Return (\_SB.BPM2.TEMP (TH500_THERMAL_ZONE_SOC4) )} // get current temp
      Method(_TC1) { Return (\_SB.BPM2.TC1T) }
      Method(_TC2) { Return (\_SB.BPM2.TC2T) }
      Method(_CRT) { Return (\_SB.BPM2.CRTT) }
      Name(_TSP, TH500_THERMAL_ZONE_TSP)
      Name(_TZP, TEMP_POLL_TIME_100MS)
      Name (_STR, Unicode ("Thermal Zone Skt2 SOC4"))
    }

    ThermalZone (TZ2D) {
      Method(_TMP) { Return (\_SB.BPM2.TEMP (TH500_THERMAL_ZONE_TJ_MAX) )} // get current temp
      Method(_TC1) { Return (\_SB.BPM2.TC1T) }
      Method(_TC2) { Return (\_SB.BPM2.TC2T) }
      Method(_CRT) { Return (\_SB.BPM2.CRTT) }
      Name(_TSP, TH500_THERMAL_ZONE_TSP)
      Name(_TZP, TEMP_POLL_TIME_100MS)
      Name (_STR, Unicode ("Thermal Zone Skt2 TJMax"))
    }

    ThermalZone (TZ2E) {
      Method(_TMP) { Return (\_SB.BPM2.TEMP (TH500_THERMAL_ZONE_TJ_MIN) )} // get current temp
      Method(_TC1) { Return (\_SB.BPM2.TC1T) }
      Method(_TC2) { Return (\_SB.BPM2.TC2T) }
      Method(_CRT) { Return (\_SB.BPM2.CRTT) }
      Name(_TSP, TH500_THERMAL_ZONE_TSP)
      Name(_TZP, TEMP_POLL_TIME_100MS)
      Name (_STR, Unicode ("Thermal Zone Skt2 TJMin"))
    }

    ThermalZone (TZ2F) {
      Method(_TMP) { Return (\_SB.BPM2.TEMP (TH500_THERMAL_ZONE_TJ_AVG) )} // get current temp
      Method(_TC1) { Return (\_SB.BPM2.TC1T) }
      Method(_TC2) { Return (\_SB.BPM2.TC2T) }
      Method(_CRT) { Return (\_SB.BPM2.CRTT) }
      Name(_TSP, TH500_THERMAL_ZONE_TSP)
      Name(_TZP, TEMP_POLL_TIME_100MS)
      Name (_STR, Unicode ("Thermal Zone Skt2 TJAvg"))
    }
    //---------------------------------------------------------------------
    // Module Power Device Socket 2
    //---------------------------------------------------------------------
    Device (PM20)
    {
      Name (_HID, "ACPI000D")
      Name (_UID, 20)
      Name (CAI, PWR_METER_MEASUREMENT_SAMPLING_TIME_50MS)
      Name (HWLT, 0)
      Name (MINP, 0x00000000)
      Name (MAXP, 0x00000000)

      // _PMD method return code - List of power meter devices
      Name (PMD, Package() {
        \_SB.PM20
      })

      // _PMC method result code
      Name (PMC, Package() {
        BIT (PWR_METER_SUPPORTS_MEASUREMENT),
        PWR_METER_MEASUREMENT_IN_MW,
        PWR_METER_MEASURE_OP_PWR,
        PWR_METER_MEASUREMENT_ACCURACY_100,
        \_SB.PM20.CAI,
        PWR_METER_MEASUREMENT_SAMPLING_TIME_50MS,
        PWR_METER_MEASUREMENT_SAMPLING_TIME_1SEC,
        PWR_METER_HYSTERESIS_MARGIN_UNKNOWN,
        PWR_METER_HW_LIMIT_RW,
        \_SB.PM20.MINP,
        \_SB.PM20.MAXP,
        "",                                   // Model Number - NULL
        "",                                   // Serial Number - NULL
        "Module Power Socket 2"               // OEM Information - "Module Power Socket 2"
      })

      Method (_PMC) {
        Return (PMC)
      }

      Method (_PAI, 1, Serialized, 0, IntObj, IntObj) {
        If (Arg0 == PWR_METER_MEASUREMENT_SAMPLING_TIME_50MS) {
          Store (PWR_METER_MEASUREMENT_SAMPLING_TIME_50MS, CAI)
          Notify (\_SB.PM20, PWR_METER_NOTIFY_CONFIG)
          Return (PWR_METER_SUCCESS)
        } ElseIf (Arg0 == PWR_METER_MEASUREMENT_SAMPLING_TIME_1SEC) {
          Store (PWR_METER_MEASUREMENT_SAMPLING_TIME_1SEC, CAI)
          Notify (\_SB.PM20, PWR_METER_NOTIFY_CONFIG)
          Return (PWR_METER_SUCCESS)
        }
        Return (PWR_METER_OUT_OF_RANGE)
      }

      Method (_GAI) {
        Return (CAI)
      }

      Method (_PMD) {
        Return (PMD)
      }

      Method (_PMM) {
        Local0 = 0
        Local0 = \_SB.BPM2.TELM(TH500_MODULE_PWR, CAI)
        Return (Local0)
      }

      Method (_GHL) {
        Return (PWR_METER_ERR_RETURN)
      }

      Method (_SHL, 1, Serialized, 0, IntObj, IntObj) {
        Store (Arg0, HWLT)
        Return (PWR_METER_UNKNOWN_HW_ERR)
      }
    }

    //---------------------------------------------------------------------
    // TH500 Power Device Socket 2
    //---------------------------------------------------------------------
    Device (PM21)
    {
      Name (_HID, "ACPI000D")
      Name (_UID, 21)
      Name (CAI, PWR_METER_MEASUREMENT_SAMPLING_TIME_50MS)
      Name (HWLT, 0)
      Name (MINP, 0xAAAAAAAA)
      Name (MAXP, 0xAAAAAAAA)

      // _PMD method return code - List of power meter devices
      Name (PMD, Package() {
        \_SB.PM21
      })

      // _PMC method result code
      Name (PMC, Package() {
        BIT (PWR_METER_SUPPORTS_MEASUREMENT) | BIT (PWR_METER_SUPPORTS_HW_LIMITS) |
        BIT (PWR_METER_SUPPORTS_NOTIFY_HW_LIMITS),
        PWR_METER_MEASUREMENT_IN_MW,
        PWR_METER_MEASURE_OP_PWR,
        PWR_METER_MEASUREMENT_ACCURACY_100,
        \_SB.PM21.CAI,
        PWR_METER_MEASUREMENT_SAMPLING_TIME_50MS,
        PWR_METER_MEASUREMENT_SAMPLING_TIME_1SEC,
        PWR_METER_HYSTERESIS_MARGIN_UNKNOWN,
        PWR_METER_HW_LIMIT_RW,
        \_SB.PM21.MINP,
        \_SB.PM21.MAXP,
        "",                                  // Model Number - NULL
        "",                                  // Serial Number - NULL
        "TH500 Power Socket 2"               // OEM Information - "TH500 Power Socket 2"
      })

      Method (_PMC) {
        Return (PMC)
      }

      Method (_PAI, 1, Serialized, 0, IntObj, IntObj) {
        If (Arg0 == PWR_METER_MEASUREMENT_SAMPLING_TIME_50MS) {
          Store (PWR_METER_MEASUREMENT_SAMPLING_TIME_50MS, CAI)
          Notify (\_SB.PM21, PWR_METER_NOTIFY_CONFIG)
          Return (PWR_METER_SUCCESS)
        } ElseIf (Arg0 == PWR_METER_MEASUREMENT_SAMPLING_TIME_1SEC) {
          Store (PWR_METER_MEASUREMENT_SAMPLING_TIME_1SEC, CAI)
          Notify (\_SB.PM21, PWR_METER_NOTIFY_CONFIG)
          Return (PWR_METER_SUCCESS)
        }
        Return (PWR_METER_OUT_OF_RANGE)
      }

      Method (_GAI) {
        Return (CAI)
      }

      Method (_PMD) {
        Return (PMD)
      }

      Method (_PMM) {
        Local0 = 0
        Local0 = \_SB.BPM2.TELM(TH500_TH500_PWR, CAI)
        Return (Local0)
      }

      Method(_GHL) {
        Local0 = 0
        Local1 = TH500_PWR_LIMIT_ID_TH500_INP_EDPC_MW
        Local0 = \_SB.BPM2.GPRL (Local1)
        Return (Local0)
      }

      Method (_SHL, 1, Serialized, 0, IntObj, IntObj) {
        Local0 = 0
        Local1 = TH500_PWR_LIMIT_ID_TH500_INP_EDPC_MW
        If ((Arg0 <= MINP) && (Arg0 >= MAXP)) {
          Return (PWR_METER_OUT_OF_RANGE)
        }
        Local0 = \_SB.BPM2.SPRL (Local1, Arg0)
        If (Local0 == 0) {
          If (Arg0 != HWLT) {
            Store (Arg0, HWLT)
            Notify (\_SB.PM21, PWR_METER_NOTIFY_CAP)
          }
          Notify (\_SB.PM21, PWR_METER_NOTIFY_CAPPING)
        }
        Return (Local0)
      }
    }

    //---------------------------------------------------------------------
    // CPU Power Device Socket 2
    //---------------------------------------------------------------------
    Device (PM22)
    {
      Name (_HID, "ACPI000D")
      Name (_UID, 12)
      Name (CAI, PWR_METER_MEASUREMENT_SAMPLING_TIME_50MS)
      Name (HWLT, 0)
      Name (MINP, 0x00000000)
      Name (MAXP, 0x00000000)

      // _PMD method return code - List of power meter devices
      Name (PMD, Package() {
        \_SB.PM22
      })

      // _PMC method result code
      Name (PMC, Package() {
        BIT (PWR_METER_SUPPORTS_MEASUREMENT),
        PWR_METER_MEASUREMENT_IN_MW,
        PWR_METER_MEASURE_OP_PWR,
        PWR_METER_MEASUREMENT_ACCURACY_100,
        \_SB.PM22.CAI,
        PWR_METER_MEASUREMENT_SAMPLING_TIME_50MS,
        PWR_METER_MEASUREMENT_SAMPLING_TIME_1SEC,
        PWR_METER_HYSTERESIS_MARGIN_UNKNOWN,
        PWR_METER_HW_LIMIT_RW,
        \_SB.PM22.MINP,
        \_SB.PM22.MAXP,
        "",                                // Model Number - NULL
        "",                                // Serial Number - NULL
        "CPU Power Socket 2"               // OEM Information - "CPU Power Socket 2"
      })

      Method (_PMC) {
        Return (PMC)
      }

      Method (_PAI, 1, Serialized, 0, IntObj, IntObj) {
        If (Arg0 == PWR_METER_MEASUREMENT_SAMPLING_TIME_50MS) {
          Store (PWR_METER_MEASUREMENT_SAMPLING_TIME_50MS, CAI)
          Notify (\_SB.PM22, PWR_METER_NOTIFY_CONFIG)
          Return (PWR_METER_SUCCESS)
        } ElseIf (Arg0 == PWR_METER_MEASUREMENT_SAMPLING_TIME_1SEC) {
          Store (PWR_METER_MEASUREMENT_SAMPLING_TIME_1SEC, CAI)
          Notify (\_SB.PM22, PWR_METER_NOTIFY_CONFIG)
          Return (PWR_METER_SUCCESS)
        }
        Return (PWR_METER_OUT_OF_RANGE)
      }

      Method (_GAI) {
        Return (CAI)
      }

      Method (_PMD) {
        Return (PMD)
      }

      Method (_PMM) {
        Local0 = 0
        Local0 = \_SB.BPM2.TELM(TH500_CPU_PWR, CAI)
        Return (Local0)
      }

      Method (_GHL) {
        Return (PWR_METER_ERR_RETURN)
      }

      Method (_SHL, 1, Serialized, 0, IntObj, IntObj) {
        Store (Arg0, HWLT)
        Return (PWR_METER_UNKNOWN_HW_ERR)
      }
    }

    //---------------------------------------------------------------------
    // SOC Power Device Socket 2
    //---------------------------------------------------------------------
    Device (PM23)
    {
      Name (_HID, "ACPI000D")
      Name (_UID, 23)
      Name (CAI, PWR_METER_MEASUREMENT_SAMPLING_TIME_50MS)
      Name (HWLT, 0)
      Name (MINP, 0x00000000)
      Name (MAXP, 0x00000000)

      // _PMD method return code - List of power meter devices
      Name (PMD, Package() {
        \_SB.PM23
      })

      // _PMC method result code
      Name (PMC, Package() {
        BIT (PWR_METER_SUPPORTS_MEASUREMENT),
        PWR_METER_MEASUREMENT_IN_MW,
        PWR_METER_MEASURE_OP_PWR,
        PWR_METER_MEASUREMENT_ACCURACY_100,
        \_SB.PM23.CAI,
        PWR_METER_MEASUREMENT_SAMPLING_TIME_50MS,
        PWR_METER_MEASUREMENT_SAMPLING_TIME_1SEC,
        PWR_METER_HYSTERESIS_MARGIN_UNKNOWN,
        PWR_METER_HW_LIMIT_RW,
        \_SB.PM23.MINP,
        \_SB.PM23.MAXP,
        "",                                // Model Number - NULL
        "",                                // Serial Number - NULL
        "SoC Power Socket 2"               // OEM Information - "SoC Power Socket 2"
      })

      Method (_PMC) {
        Return (PMC)
      }

      Method (_PAI, 1, Serialized, 0, IntObj, IntObj) {
        If (Arg0 == PWR_METER_MEASUREMENT_SAMPLING_TIME_50MS) {
          Store (PWR_METER_MEASUREMENT_SAMPLING_TIME_50MS, CAI)
          Notify (\_SB.PM23, PWR_METER_NOTIFY_CONFIG)
          Return (PWR_METER_SUCCESS)
        } ElseIf (Arg0 == PWR_METER_MEASUREMENT_SAMPLING_TIME_1SEC) {
          Store (PWR_METER_MEASUREMENT_SAMPLING_TIME_1SEC, CAI)
          Notify (\_SB.PM23, PWR_METER_NOTIFY_CONFIG)
          Return (PWR_METER_SUCCESS)
        }
        Return (PWR_METER_OUT_OF_RANGE)
      }

      Method (_GAI) {
        Return (CAI)
      }

      Method (_PMD) {
        Return (PMD)
      }

      Method (_PMM) {
        Local0 = 0
        Local0 = \_SB.BPM2.TELM(TH500_SOC_PWR, CAI)
        Return (Local0)
      }

      Method (_GHL) {
        Return (PWR_METER_ERR_RETURN)
      }

      Method (_SHL, 1, Serialized, 0, IntObj, IntObj) {
        Store (Arg0, HWLT)
        Return (PWR_METER_UNKNOWN_HW_ERR)
      }
    }
  } //Scope(_SB)
}