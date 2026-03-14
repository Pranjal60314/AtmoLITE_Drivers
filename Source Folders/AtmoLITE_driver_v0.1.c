#include <mss_uart.h>
#include <stdint.h>
#include <AtmoLITE_driver_v0.1.h>

/*
Current Scope
-Communication Framework for TC-IF and SC-IF
-CRC8 implementation
-
*/



/*-----------Utilities-------------------*/
static uint8_t packet_nr_handler(){//***to be replaced with 
    static uint8_t packet_nr=0;
    return packet_nr++;
}

uint8_t calc_crc8(const void * data, size_t size) {
    uint8_t val = 0;

    uint8_t * pos = (uint8_t *) data;
    uint8_t * end = pos + size;

    while (pos < end) {
        val = CRC_TABLE[val ^ *pos];
        pos++;
    }

    return val;
}


/*return an array of buffer*/
uint32_t read_exact(uint8_t *buf, uint32_t len)
{
    uint32_t received = 0;

    while (received < len) {
        received += MSS_UART_get_rx(
                        &g_mss_uart0,
                        &buf[received],
                        len - received);
    }

    return received;
}


/*-----------------------Telecommand Interface-----------------------*/

/*Builds Header file ensuring no value remains missing or unaccounted for*/
void header_build_buff(
    uint8_t packet_nr,
    uint8_t subprotocol,
    uint8_t subcommand,
    uint8_t param0,
    uint8_t param1,
    uint8_t param2,
    uint8_t param3,
    uint8_t param4,
    uint8_t param5,
    uint8_t param6,
    uint8_t param7,
    uint32_t data_len_bytes,
    uint8_t out_buf[16] // must be at least 16 bytes
)
{
    out_buf[0]  = LOGICAL_ADDRESS;
    out_buf[1]  = subprotocol;
    out_buf[2]  = packet_nr;
    out_buf[3]  = subcommand;
    out_buf[4]  = param0;
    out_buf[5]  = param1;
    out_buf[6]  = param2;
    out_buf[7]  = param3;
    out_buf[8]  = param4;
    out_buf[9]  = param5;
    out_buf[10] = param6;
    out_buf[11] = param7;
    out_buf[12] = (uint8_t)(data_len_bytes & 0xFF);
    out_buf[13] = (uint8_t)((data_len_bytes >> 8) & 0xFF);
    out_buf[14] = (uint8_t)((data_len_bytes >> 16) & 0xFF);
    out_buf[15]=calc_crc8(out_buf, 15);//calculating crc8

}

/*
Things to keep in mind
- The packet number is generated and returned for tracking purposes.
- The transmission is synchronous and blocks until the packet is sent.
*/

/*Makes a packet from the given parameters and transmits it*/
uint8_t telecommand_transmission( 
    uint8_t  subprotocol,
    uint8_t  subcommand,
    uint8_t param0,
    uint8_t param1,
    uint8_t param2,
    uint8_t param3,
    uint8_t param4,
    uint8_t param5,
    uint8_t param6,
    uint8_t param7,
    const uint8_t *data,
    uint32_t data_len
)
{
    uint8_t packet[PACKET_LENGTH];    
    uint32_t idx = 0;

    uint8_t packet_nr=packet_nr_handler();//**initiate this before the transmission so reply can be read at the same time(low byte of timestamp value in milli second)

    header_build_buff(
        packet_nr,
        subprotocol,
        subcommand,
        param0,
        param1,
        param2,
        param3,
        param4,
        param5,
        param6,
        param7,
        data_len,
        packet
    );

    idx += 16;

    if (data_len > 0 && data != NULL) {
        for (uint32_t i = 0; i < data_len; i++) {
            packet[idx++] = data[i];
        }
        packet[idx++]=calc_crc8(data, data_len);
    }

    MSS_UART_polled_tx(&g_mss_uart0, packet, idx);

    //delay(100);

    return packet_nr;
}

/*To receive and validate the data that will be received*/
/*Returns 0 if successful, error code otherwise*/
/*Data after validation is stored in tc_rx_data_buffer*/
/*out_len is number of bytes received in the data buffer*/
uint8_t telecommand_receive(
        uint8_t *out_data,
        uint32_t *out_len,
        uint8_t PACKET_NR){

    //Recieve Header Data
    uint8_t tc_rx_header_buff[16];
    read_exact(tc_rx_header_buff, 16);

    //Check for correctness
    if (tc_rx_header_buff[0]!=LOGICAL_ADDRESS)
    {
        return LOGICAL_ADDRESS_ERROR;
    }

    if (tc_rx_header_buff[3] != 0)
    {
        return tc_rx_header_buff[3];
    }

    uint8_t crc_8;
    crc_8=calc_crc8(tc_rx_header_buff,15);
    if (tc_rx_header_buff[15]!=crc_8)
    {
        return HEADER_CRC_ERROR;
    }

    if (tc_rx_header_buff[2]!=PACKET_NR)
    {
        return PACKET_NR_ERROR;
    }

    if ( (tc_rx_header_buff[1] & TC_REPLY_MASK) != TC_REPLY_PATTERN )
    {
    return NOT_TC_REPLY_SUBPROTOCOL;
    }

    //Receive the actual data
    uint32_t xlen =tc_rx_header_buff[12] | (tc_rx_header_buff[13] << 8) | (tc_rx_header_buff[14] << 16);    
    
    if(xlen>ATMOLITE_TC_MAX_DATA)
    {
        return DATA_LENGTH_ERROR;
    }       

    //Read the data
    uint8_t data_buf[ATMOLITE_TC_MAX_DATA];
    read_exact(data_buf, xlen);

    uint8_t data_crc[1];
    read_exact(data_crc, 1);

    //Check data CRC
    uint8_t data_crc_8;
    data_crc_8=calc_crc8(data_buf, xlen);
    if (data_crc[0]!=data_crc_8)
    {
        return DATA_CRC_ERROR;
    }

    //storing the data in proper container for further use
    memcpy(out_data,data_buf,xlen);
    *out_len = xlen;

    return 0;
}

/*To Receive and Validate Science Telemetry and image*/
/*To validate image size and timestamp will be done by the caller(Pending)*/
/*out_len is number of bytes received in the data buffer*/
uint8_t science_receive(
        uint8_t *out_data,
        uint32_t *out_len, 
        uint8_t *is_zipped){

    //Recieve Header Data
    uint8_t sc_rx_header_buff[16];
    read_exact(sc_rx_header_buff, 16);

    //Check for correctness
    if (sc_rx_header_buff[0]!=LOGICAL_ADDRESS)
    {
        return LOGICAL_ADDRESS_ERROR;
    }

    uint8_t crc_8;
    crc_8=calc_crc8(sc_rx_header_buff,15);
    if (sc_rx_header_buff[15]!=crc_8)
    { 
        return HEADER_CRC_ERROR;
    }
    
    if ( (sc_rx_header_buff[1] & SCIENCE_MASK) != SCIENCE_PATTERN )
    {
    return NOT_SCIENCE_TELEMETRY_SUBPROTOCOL;
    }

    if ((sc_rx_header_buff[1]&0x0F)==0x0A||(sc_rx_header_buff[1]&0x0F)==0x08){

        return SCIENCE_TELEMETRY_SUBPROTOCOL_ERROR;
    }

    *is_zipped = (sc_rx_header_buff[1] & ZIP_FLAG_MASK) ? 1 : 0;

    //Receive the actual data
    uint32_t xlen =sc_rx_header_buff[12] | (sc_rx_header_buff[13] << 8) | (sc_rx_header_buff[14] << 16);    
    if(xlen>ATMOLITE_TC_MAX_DATA)
    {
        return DATA_LENGTH_ERROR;
    }   
    //Read the data
    uint8_t data_buf[ATMOLITE_TC_MAX_DATA];
    read_exact(data_buf, xlen);

    uint8_t data_crc[1];
    read_exact(data_crc, 1);

    //Check data CRC
    uint8_t data_crc_8;
    data_crc_8=calc_crc8(data_buf, xlen);
    if (data_crc[0]!=data_crc_8)
    {
        return DATA_CRC_ERROR;
    }

    //storing the data in proper container for further use
    memcpy(out_data,data_buf,xlen);
    *out_len=xlen;

    return 0;
}

/*Telecommand Write Registers*/
/* 
- The data buffer is not copied locally; the function uses the caller’s memory directly via pointer.
- The caller must ensure that 'value' points to at least 'count' valid bytes.
*/
void tc_write_registers(
        uint8_t mode,/*REGISTER MODE=0x00 BLOCK MODE= 0x10*/
        uint16_t id, 
        uint8_t *value, 
        uint16_t count
         ){

    //Sub-Protocol
    uint8_t sub_protocol=WRITE;//Write

    //SubCommand
    uint8_t sub_command=mode;//Register write mode

    //Parameters
    uint8_t param0= id & 0xFF;
    uint8_t param1= ( id >> 8 ) & 0xFF;//little endian format

    uint8_t param2= count & 0xFF;
    uint8_t param3= ( count >> 8) & 0xFF;

    telecommand_transmission(
    sub_protocol,
    sub_command,
    param0,
    param1,
    param2,
    param3,
    0,0,0,0,
    value,
    count*2//each register is 2 bytes
    );
}

/* Telecommand Read Registers
 * Reads 'len' bytes starting from register 'reg'.
 * The received data is written into caller-provided buffer 'out_data'.
 */
uint8_t tc_read(
    uint8_t mode,
    uint16_t reg,
    uint16_t len,
    uint8_t *out_data)
{
    uint8_t sub_protocol = READ;
    uint8_t sub_command  = mode;

    uint8_t param0 = reg & 0xFF;
    uint8_t param1 = (reg >> 8) & 0xFF;

    uint8_t param2 = len & 0xFF;
    uint8_t param3 = (len >> 8) & 0xFF;

    uint8_t pkt = telecommand_transmission(
        sub_protocol,
        sub_command,
        param0,
        param1,
        param2,
        param3,
        0,0,0,0,
        NULL,
        0);

    uint32_t out_len = 0;

    uint8_t err = telecommand_receive(out_data, &out_len, pkt);
    if (err != 0)
        return err;

    if (out_len != len)
        return DATA_LENGTH_ERROR;

    return 0;
}

/*--------------------Initialise-------------------------*/
void instrument_safe_init(void)
{
    //Disable instrument control bits (Reg 9)
    uint16_t instr_ctrl = 0x0000;
    tc_write_registers(REGISTER_MODE, 9, (uint8_t*)&instr_ctrl, 2);

    //LSD Safe Config GSENSE 400 (Registers 45–67)
    uint16_t lsd_config[23] = {0};

    lsd_config[0] = 0;        // IMAQ_Control OFF
    lsd_config[1] = 0;        // Integration Time in SEC
    lsd_config[2] = 500;      // Integration Time MS
    lsd_config[5] = 0;        // Start X
    lsd_config[6] = 0;        // Start Y
    lsd_config[7] = 2048;     // Size X
    lsd_config[8] = 2040;     // Size Y
    lsd_config[9] = 1;        // Binning X
    lsd_config[10] = 1;       // Binning Y
    lsd_config[15] = 0;       // Train Mode OFF

    tc_write_registers(
        REGISTER_MODE,
        45,
        (uint8_t*)lsd_config,
        23
    );

    //ACC Safe Config (Registers 93–107)
    uint16_t acc_config[15] = {0};

    acc_config[0] = 0;      // IMAQ_Control OFF
    acc_config[1] = 4;      // Frame Time SEC
    acc_config[4] = 200;    // IntegrationTime_MS
    acc_config[7] = 1972;   // Size_X
    acc_config[8] = 1160;   // Size_Y

    tc_write_registers(
        REGISTER_MODE,
        93,
        (uint8_t*)acc_config,
        15
    );

    //Disable Ethernet (Reg 125)
    uint16_t eth_ctrl = 0;
    tc_write_registers(REGISTER_MODE, 125, (uint8_t*)&eth_ctrl, 2);
}


