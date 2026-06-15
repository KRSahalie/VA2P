#!/bin/bash
# ============================================================
# Uso: ./run_aligner_regression.sh [NUM_TESTS]
# ============================================================

# Configurar herramientas
source /mnt/vol_NFS_rh003/estudiantes/archivos_config/synopsys_tools2.sh

NUM_TESTS=${1:-5}
MAX_RETRIES=2

echo "=========================================="
echo "  REGRESIÓN ALIGNER - $NUM_TESTS pruebas"
echo "=========================================="

# Compilar una sola vez
echo ""
echo "Compilando testbench..."
vcs -sverilog -timescale=1ns/1ps \
    -ntb_opts uvm-1.2 \
    tb_top.sv \
    -o simv \
    -l compile.log

if [ $? -ne 0 ]; then
    echo "ERROR: Falló la compilación"
    tail -20 compile.log
    exit 1
fi
echo "Compilación exitosa"

# Crear directorio para logs
mkdir -p logs

# Archivo de pruebas fallidas
> failed.txt

# Ejecutar pruebas
PASSED=0
FAILED=0

for i in $(seq 1 $NUM_TESTS); do
    
    # ============================================================
    # GENERAR PARÁMETROS ALEATORIOS
    # ============================================================
    
    # General
    SEMILLA=$((RANDOM * 32768 + RANDOM))
    
    # Modos de test (20% cada uno)
    MODOS=("FULL" "APB_ONLY" "MD_ONLY")
    MODOS_PESO=60  # 60% FULL, 20% APB_ONLY, 20% MD_ONLY
    RAND_MODO=$((RANDOM % 100))
    if [ $RAND_MODO -lt 60 ]; then
        TEST_MODE="FULL"
    elif [ $RAND_MODO -lt 80 ]; then
        TEST_MODE="APB_ONLY"
    else
        TEST_MODE="MD_ONLY"
    fi
    
    # APB
    APB_NUM_TRANS=$((50 + RANDOM % 450))  # 50-500
    APB_PESO_CTRL_VALID=$((RANDOM % 41))       # 0-40
    APB_PESO_CTRL_INVALID=$((RANDOM % 31))     # 0-30
    APB_PESO_IRQEN=$((RANDOM % 31))            # 0-30
    APB_PESO_STATUS=$((RANDOM % 21))           # 0-20
    APB_PESO_IRQ=$((RANDOM % 21))              # 0-20
    APB_PESO_IRQ_CLEAR=$((RANDOM % 21))        # 0-20
    
    APB_CTRL_SIZE_MIN=$((1 + RANDOM % 4))      # 1-4
    APB_CTRL_SIZE_MAX=$((APB_CTRL_SIZE_MIN + RANDOM % (5 - APB_CTRL_SIZE_MIN)))
    APB_CTRL_OFFSET_MIN=$((RANDOM % 4))        # 0-3
    APB_CTRL_OFFSET_MAX=$((APB_CTRL_OFFSET_MIN + RANDOM % (4 - APB_CTRL_OFFSET_MIN)))
    
    # MD
    MD_NUM_PKTS=$((20 + RANDOM % 200))          # 20-220
    MD_RETARDO_MIN=$((RANDOM % 5))              # 0-4
    MD_RETARDO_MAX=$((MD_RETARDO_MIN + RANDOM % 16 + 1))  # hasta 20
    MD_PESO_LEGAL=$((RANDOM % 101))             # 0-100
    MD_PESO_ILEGAL=$((100 - MD_PESO_LEGAL))
    
    PATRONES=("RANDOM" "INCR" "DECR" "FIXED" "ZEROS" "ONES")
    MD_PATRON=${PATRONES[$((RANDOM % 6))]}
    
    # Interrupciones (random enable/disable)
    IRQ_EN_RX_EMPTY=$((RANDOM % 2))
    IRQ_EN_RX_FULL=$((RANDOM % 2))
    IRQ_EN_TX_EMPTY=$((RANDOM % 2))
    IRQ_EN_TX_FULL=$((RANDOM % 2))
    IRQ_EN_MAX_DROP=$((RANDOM % 2))
    
    # CTRL fijo (30% de las veces usar valores fijos)
    if [ $((RANDOM % 10)) -lt 3 ]; then
        CTRL_SIZE=$((1 + RANDOM % 4))
        CTRL_OFFSET=$((RANDOM % 4))
        # Asegurar que sea válido si es posible
        if [ $(( (4 + CTRL_OFFSET) % CTRL_SIZE )) -ne 0 ]; then
            CTRL_OFFSET=0
        fi
    else
        CTRL_SIZE=-1
        CTRL_OFFSET=-1
    fi
    
    # Duración del test (10% de las veces usar duración fija)
    if [ $((RANDOM % 10)) -lt 1 ]; then
        TEST_DURATION_US=$((50 + RANDOM % 450))
    else
        TEST_DURATION_US=0
    fi
    
    # Timeout
    TIMEOUT_MS=$((100 + RANDOM % 400))
    
    # ============================================================
    # MOSTRAR CONFIGURACIÓN
    # ============================================================
    echo ""
    echo "=========================================="
    echo "  Test $i/$NUM_TESTS"
    echo "=========================================="
    echo "  SEMILLA         = $SEMILLA"
    echo "  TEST_MODE       = $TEST_MODE"
    echo "  TIMEOUT_MS      = $TIMEOUT_MS"
    echo "------------------------------------------"
    echo "  APB:"
    echo "    NUM_TRANS      = $APB_NUM_TRANS"
    echo "    PESOS          = V:$APB_PESO_CTRL_VALID I:$APB_PESO_CTRL_INVALID"
    echo "                   E:$APB_PESO_IRQEN S:$APB_PESO_STATUS"
    echo "                   R:$APB_PESO_IRQ C:$APB_PESO_IRQ_CLEAR"
    echo "    CTRL_SIZE      = [$APB_CTRL_SIZE_MIN : $APB_CTRL_SIZE_MAX]"
    echo "    CTRL_OFFSET    = [$APB_CTRL_OFFSET_MIN : $APB_CTRL_OFFSET_MAX]"
    echo "------------------------------------------"
    echo "  MD:"
    echo "    NUM_PKTS       = $MD_NUM_PKTS"
    echo "    RETARDO        = [$MD_RETARDO_MIN : $MD_RETARDO_MAX]"
    echo "    PESOS          = L:$MD_PESO_LEGAL I:$MD_PESO_ILEGAL"
    echo "    PATRON         = $MD_PATRON"
    echo "------------------------------------------"
    echo "  INTERRUPCIONES:"
    echo "    RX_EMPTY=$IRQ_EN_RX_EMPTY RX_FULL=$IRQ_EN_RX_FULL"
    echo "    TX_EMPTY=$IRQ_EN_TX_EMPTY TX_FULL=$IRQ_EN_TX_FULL"
    echo "    MAX_DROP=$IRQ_EN_MAX_DROP"
    echo "------------------------------------------"
    echo "  ESPECÍFICOS:"
    echo "    CTRL_FIXED     = size=$CTRL_SIZE offset=$CTRL_OFFSET"
    echo "    DURATION_US    = $TEST_DURATION_US"
    echo "=========================================="
    
    # ============================================================
    # EJECUTAR TEST
    # ============================================================
    
    LOG_FILE="logs/test_${i}.log"
    
    # Construir comando con todos los plusargs
    CMD="./simv \
        +SEMILLA=$SEMILLA \
        +TEST_MODE=$TEST_MODE \
        +TIMEOUT_MS=$TIMEOUT_MS \
        +APB_NUM_TRANS=$APB_NUM_TRANS \
        +APB_PESO_CTRL_VALID=$APB_PESO_CTRL_VALID \
        +APB_PESO_CTRL_INVALID=$APB_PESO_CTRL_INVALID \
        +APB_PESO_IRQEN=$APB_PESO_IRQEN \
        +APB_PESO_STATUS=$APB_PESO_STATUS \
        +APB_PESO_IRQ=$APB_PESO_IRQ \
        +APB_PESO_IRQ_CLEAR=$APB_PESO_IRQ_CLEAR \
        +APB_CTRL_SIZE_MIN=$APB_CTRL_SIZE_MIN \
        +APB_CTRL_SIZE_MAX=$APB_CTRL_SIZE_MAX \
        +APB_CTRL_OFFSET_MIN=$APB_CTRL_OFFSET_MIN \
        +APB_CTRL_OFFSET_MAX=$APB_CTRL_OFFSET_MAX \
        +MD_NUM_PKTS=$MD_NUM_PKTS \
        +MD_RETARDO_MIN=$MD_RETARDO_MIN \
        +MD_RETARDO_MAX=$MD_RETARDO_MAX \
        +MD_PESO_LEGAL=$MD_PESO_LEGAL \
        +MD_PESO_ILEGAL=$MD_PESO_ILEGAL \
        +MD_PATRON=$MD_PATRON \
        +IRQ_EN_RX_EMPTY=$IRQ_EN_RX_EMPTY \
        +IRQ_EN_RX_FULL=$IRQ_EN_RX_FULL \
        +IRQ_EN_TX_EMPTY=$IRQ_EN_TX_EMPTY \
        +IRQ_EN_TX_FULL=$IRQ_EN_TX_FULL \
        +IRQ_EN_MAX_DROP=$IRQ_EN_MAX_DROP \
        +CTRL_SIZE=$CTRL_SIZE \
        +CTRL_OFFSET=$CTRL_OFFSET \
        +TEST_DURATION_US=$TEST_DURATION_US \
        +UVM_TESTNAME=test_general \
        +vcs+lic+wait"
    
    # Ejecutar con reintentos
    RETRIES=0
    TEST_PASSED=0
    
    while [ $RETRIES -lt $MAX_RETRIES ] && [ $TEST_PASSED -eq 0 ]; do
        if [ $RETRIES -gt 0 ]; then
            echo "  Reintento $RETRIES/$MAX_RETRIES..."
            # Nueva semilla en reintento
            CMD=$(echo $CMD | sed "s/+SEMILLA=$SEMILLA/+SEMILLA=$((SEMILLA + RETRIES))/")
        fi
        
        eval $CMD > $LOG_FILE 2>&1
        
        HAS_PASSED=$(grep -c "TEST PASADO" $LOG_FILE)
        HAS_ERROR=$(grep -E "UVM_ERROR|TEST FALLIDO" $LOG_FILE | grep -cv "UVM_ERROR :[ ]*0$")
        
        if [ "$HAS_PASSED" -gt 0 ] && [ "$HAS_ERROR" -eq 0 ]; then
            TEST_PASSED=1
        else
            RETRIES=$((RETRIES + 1))
        fi
    done
    
    # ============================================================
    # RESULTADO
    # ============================================================
    
    if [ $TEST_PASSED -eq 1 ]; then
        echo " PASS"
        PASSED=$((PASSED + 1))
        # Guardar configuración exitosa
        echo "Test $i: SEMILLA=$SEMILLA TEST_MODE=$TEST_MODE MD_PATRON=$MD_PATRON" >> logs/passed_configs.txt
    else
        echo "FAIL"
        FAILED=$((FAILED + 1))
        # Guardar configuración fallida con conteo de errores
        ERROR_COUNT=$(grep -cE "UVM_ERROR" $LOG_FILE || echo "0")
        echo "Test $i: SEMILLA=$SEMILLA TEST_MODE=$TEST_MODE APB_NUM_TRANS=$APB_NUM_TRANS MD_NUM_PKTS=$MD_NUM_PKTS MD_PATRON=$MD_PATRON ERRORS=$ERROR_COUNT" >> failed.txt
        # Mover log de fallo para análisis
        mv $LOG_FILE logs/failed_test_${i}.log
    fi
    
    # Limpiar archivos temporales para no acumular
    rm -f uvm_dpi_comm.so uvm_dpi_comm.daidir uvm_dpi_comm.o 2>/dev/null
    rm -f inter.vpd 2>/dev/null
    rm -f novas* 2>/dev/null
    rm -f verdi* 2>/dev/null
    rm -f vc_hdrs.h 2>/dev/null
    
done

# ============================================================
# LIMPIEZA FINAL
# ============================================================
rm -rf simv simv.daidir csrc compile.log 2>/dev/null

# ============================================================
# REPORTE FINAL
# ============================================================
echo ""
echo "=========================================="
echo "  REGRESIÓN COMPLETADA"
echo "=========================================="
echo "  Total:   $NUM_TESTS"
echo "  Pass:    $PASSED"
echo "  Fail:    $FAILED"
echo "  Tasa:    $(echo "scale=2; $PASSED * 100 / $NUM_TESTS" | bc)%"
echo "=========================================="

if [ $FAILED -gt 0 ]; then
    echo ""
    echo "Pruebas fallidas guardadas en failed.txt"
    echo ""
    echo "Resumen de fallos:"
    cat failed.txt
    exit 1
else
    echo ""
    echo "Todas las pruebas pasaron"
    exit 0
fi
