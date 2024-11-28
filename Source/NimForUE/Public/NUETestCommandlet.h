// Fill out your copyright notice in the Description page of Project Settings.

#pragma once

#include "CoreMinimal.h"
#include "Commandlets/Commandlet.h"
#include <NimForUEFFI.h>
#include "NUETestCommandlet.generated.h"

/**
 * 
 */
extern  "C" void runNUETests();

UCLASS()
class NIMFORUE_API UNUETestCommandlet : public UCommandlet {
	GENERATED_BODY()
	
	virtual int32 Main(const FString& Params) override;

};
