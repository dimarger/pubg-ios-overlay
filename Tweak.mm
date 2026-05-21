#include <iostream>
#include <thread>
#include <chrono>
#include <atomic>
#include <mach-o/dyld.h>
#include <unistd.h>

// Подключаем KittyMemory
#include "KittyMemory/KittyMemory.hpp"

struct Vector3 { float x, y, z; };
struct TargetData { Vector3 position; int health; int team; };

std::atomic<bool> g_KeepRunning{true};
std::atomic<TargetData> g_LatestTarget{};

namespace AppOffsets {
    constexpr uintptr_t GWorld = 0x14988578;        
    constexpr uintptr_t GameInstance = 0x140;       
    constexpr uintptr_t LocalPlayers = 0x38;        
    constexpr uintptr_t PlayerController = 0x30;    
    constexpr uintptr_t MyPawn = 0x3a8;             
    
    constexpr uintptr_t RootComponent = 0x148;       
    constexpr uintptr_t RelativeLocation = 0x11C;    
    constexpr uintptr_t PlayerState = 0x3b0;         
    constexpr uintptr_t TeamID = 0x670;              
}

void MemoryReaderThread() {
    // В оригинальной KittyMemory нужно сначала инициализировать память под процесс/модуль
    KittyMemory::ProcInfo proc_info;
    uintptr_t baseAddress = 0;
    
    while (baseAddress == 0) {
        // Получаем информацию о модуле libUE4.so
        proc_info = KittyMemory::get_image_info_by_name("libUE4.so");
        baseAddress = proc_info.address;
        std::this_thread::sleep_for(std::chrono::milliseconds(500));
    }

    while (g_KeepRunning.load()) {
        // В оригинальной KittyMemory чтение происходит через KittyMemory::readData
        uintptr_t gWorld = 0;
        KittyMemory::readData((void*)(baseAddress + AppOffsets::GWorld), &gWorld, sizeof(gWorld));
        
        if (!gWorld) { 
            std::this_thread::sleep_for(std::chrono::milliseconds(100)); 
            continue; 
        }

        uintptr_t gameInstance = 0;
        KittyMemory::readData((void*)(gWorld + AppOffsets::GameInstance), &gameInstance, sizeof(gameInstance));
        
        uintptr_t localPlayersList = 0;
        KittyMemory::readData((void*)(gameInstance + AppOffsets::LocalPlayers), &localPlayersList, sizeof(localPlayersList));
        
        uintptr_t localPlayer = 0;
        KittyMemory::readData((void*)(localPlayersList), &localPlayer, sizeof(localPlayer)); 
        
        uintptr_t playerController = 0;
        KittyMemory::readData((void*)(localPlayer + AppOffsets::PlayerController), &playerController, sizeof(playerController));
        
        uintptr_t myPawn = 0;
        KittyMemory::readData((void*)(playerController + AppOffsets::MyPawn), &myPawn, sizeof(myPawn));
        
        if (myPawn) {
            uintptr_t rootComp = 0;
            KittyMemory::readData((void*)(myPawn + AppOffsets::RootComponent), &rootComp, sizeof(rootComp));
            
            Vector3 myPos = {0, 0, 0};
            KittyMemory::readData((void*)(rootComp + AppOffsets::RelativeLocation), &myPos, sizeof(myPos));
            
            uintptr_t playerState = 0;
            KittyMemory::readData((void*)(myPawn + AppOffsets::PlayerState), &playerState, sizeof(playerState));
            
            int myTeam = 0;
            KittyMemory::readData((void*)(playerState + AppOffsets::TeamID), &myTeam, sizeof(myTeam));

            TargetData data;
            data.position = myPos;
            data.health = 100; 
            data.team = myTeam;
            
            g_LatestTarget.store(data);
        }
        std::this_thread::sleep_for(std::chrono::milliseconds(10));
    }
}

__attribute__((constructor))
void Initialize() {
    std::thread readerThread(MemoryReaderThread);
    readerThread.detach();
}
