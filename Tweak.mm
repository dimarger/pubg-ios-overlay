#include <iostream>
#include <thread>
#include <chrono>
#include <atomic>
#include <mach-o/dyld.h>
#include <unistd.h>

// Подключаем KittyMemory (в облачной сборке она подтянется автоматически)
#include "KittyMemory/Memory.hpp"

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
    uintptr_t baseAddress = 0;
    while (baseAddress == 0) {
        // Получаем базу libUE4.so в памяти iOS
        baseAddress = KittyMemory::get_image_base_address("libUE4.so");
        std::this_thread::sleep_for(std::chrono::milliseconds(500));
    }

    while (g_KeepRunning.load()) {
        uintptr_t gWorld = KittyMemory::Read<uintptr_t>(baseAddress + AppOffsets::GWorld);
        if (!gWorld) { 
            std::this_thread::sleep_for(std::chrono::milliseconds(100)); 
            continue; 
        }

        uintptr_t gameInstance = KittyMemory::Read<uintptr_t>(gWorld + AppOffsets::GameInstance);
        uintptr_t localPlayersList = KittyMemory::Read<uintptr_t>(gameInstance + AppOffsets::LocalPlayers);
        uintptr_t localPlayer = KittyMemory::Read<uintptr_t>(localPlayersList); 
        uintptr_t playerController = KittyMemory::Read<uintptr_t>(localPlayer + AppOffsets::PlayerController);
        uintptr_t myPawn = KittyMemory::Read<uintptr_t>(playerController + AppOffsets::MyPawn);
        
        if (myPawn) {
            uintptr_t rootComp = KittyMemory::Read<uintptr_t>(myPawn + AppOffsets::RootComponent);
            Vector3 myPos = KittyMemory::Read<Vector3>(rootComp + AppOffsets::RelativeLocation);
            
            uintptr_t playerState = KittyMemory::Read<uintptr_t>(myPawn + AppOffsets::PlayerState);
            int myTeam = KittyMemory::Read<int>(playerState + AppOffsets::TeamID);

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
