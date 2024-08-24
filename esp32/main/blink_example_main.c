#include <stdio.h>
#include <memory.h>

#include "driver/spi_master.h"
#include "driver/spi_common.h"
#include "hal/spi_types.h"

#include "freertos/FreeRTOS.h"
#include "freertos/task.h"

#include "esp_log.h"
#include "led_strip.h"
#include "sdkconfig.h"

#include "hal/gpio_types.h"
#include "hal/gpio_ll.h"

#include "driver/gpio.h"
#include "driver/i2s.h"
#include "driver/ledc.h"

#include "soc/periph_defs.h"
#include "soc/io_mux_reg.h"
#include "soc/soc.h"
#include "soc/rtc.h"

#include "soc/i2s_struct.h"
#include "soc/i2s_reg.h"
#include "soc/i2s_periph.h"

#include "soc/gpio_periph.h"

#include "esp32/rom/lldesc.h"
#include "esp32/rom/gpio.h"

#include "esp32/rtc.h"

//#include "esp_private/periph_ctrl.h"

#include "esp_eth.h"
#include "esp_netif.h"
#include "esp_event.h"
#include "esp_log.h"

#include "lwip/ip4_addr.h"

#include "sys/socket.h"

#include "sdkconfig.h"

static const char *TAG = "spi_to_eth";
int connected = 0;

static void eth_event_handler(void *arg, esp_event_base_t event_base,
		int32_t event_id, void *event_data) {
	uint8_t mac_addr[6] = { 0 };
	/* we can get the ethernet driver handle from event data */
	esp_eth_handle_t eth_handle = *(esp_eth_handle_t*) event_data;

	switch (event_id) {
	case ETHERNET_EVENT_CONNECTED:
		esp_eth_ioctl(eth_handle, ETH_CMD_G_MAC_ADDR, mac_addr);
		ESP_LOGI(TAG, "Ethernet Link Up");
		ESP_LOGI(TAG, "Ethernet HW Addr %02x:%02x:%02x:%02x:%02x:%02x",
				mac_addr[0], mac_addr[1], mac_addr[2], mac_addr[3], mac_addr[4],
				mac_addr[5]);
		connected = 1;
		break;
	case ETHERNET_EVENT_DISCONNECTED:
		ESP_LOGI(TAG, "Ethernet Link Down");
		connected = 0;
		break;
	case ETHERNET_EVENT_START:
		ESP_LOGI(TAG, "Ethernet Started");
		break;
	case ETHERNET_EVENT_STOP:
		ESP_LOGI(TAG, "Ethernet Stopped");
		break;
	default:
		break;
	}
}

static void got_ip_event_handler(void *arg, esp_event_base_t event_base,
		int32_t event_id, void *event_data) {
	ip_event_got_ip_t *event = (ip_event_got_ip_t*) event_data;
	const esp_netif_ip_info_t *ip_info = &event->ip_info;

	ESP_LOGI(TAG, "Ethernet Got IP Address");
	ESP_LOGI(TAG, "~~~~~~~~~~~");
	ESP_LOGI(TAG, "ETHIP:" IPSTR, IP2STR(&ip_info->ip));
	ESP_LOGI(TAG, "ETHMASK:" IPSTR, IP2STR(&ip_info->netmask));
	ESP_LOGI(TAG, "ETHGW:" IPSTR, IP2STR(&ip_info->gw));
	ESP_LOGI(TAG, "~~~~~~~~~~~");
}

int udp_sock;
struct sockaddr_in sock_addr;

spi_device_handle_t handle;

static TaskHandle_t recv_task_handle;
static TaskHandle_t spi_task_handle;

static xQueueHandle spi_queue;

unsigned char *rbuf;

static void IRAM_ATTR recv_task(void *arg) {
	while(1) {
		struct sockaddr_storage addr;
		socklen_t socklen = sizeof(addr);
		recvfrom(udp_sock, rbuf, 1024, 0, (struct sockaddr*)&addr, &socklen);
		// ESP_LOGI(TAG, "Receive data: 0x%08X", *(unsigned int *)rbuf);
		xQueueSend(spi_queue, rbuf, 0);
	}
}

#define	SPI_READ_DATA		0x8F000000
#define	SPI_AMP_ONE			0x17000000
#define	SPI_AMP_TWO			0x18000000
#define	SPI_IRQ_FLAG		0x11000000

int sync_pin = 39;
int half_pin = 36;

int irq_cntr = 0;

static void /*IRAM_ATTR*/ IRAM_ATTR gpio_isr_handler(void *arg) {
	//ESP_LOGI(TAG, "IRQ Flag...");
	uint32_t half = SPI_IRQ_FLAG | gpio_get_level(half_pin);
	if (connected) {
		xQueueSendFromISR(spi_queue, &half, NULL);
		irq_cntr++;
	}
}

unsigned char *s_buf_one;
unsigned char *s_buf_two;
unsigned char *s_buf;

static void IRAM_ATTR spi_task(void *arg) {
	while (1) {
		uint32_t command = 0;
		if (xQueueReceive(spi_queue, &command, portMAX_DELAY)) {
			if ((command & 0xFF000000) == SPI_IRQ_FLAG) {
				s_buf = s_buf == s_buf_one ? s_buf_two : s_buf_one;
				int s_addr = 0;
				s_addr = (command & 0x00000001) ? 0x1000 : 0x0000;
				spi_transaction_t t;
				memset(&t, 0, sizeof(t));
				t.cmd = 0x8F;
				t.addr = s_addr << 8;
				t.flags = SPI_TRANS_MODE_QIO;
				t.length = 0;
				t.tx_buffer = NULL;
				t.rx_buffer = s_buf;
				t.rxlength = 8 * 1536;

				//esp_err_t spi_err = spi_device_polling_transmit(handle, &t);

				int b_pos = 0;
				for (int i = 0; i < 4; i++) {
					esp_err_t spi_err = spi_device_transmit(handle, &t);

					if (ESP_OK != spi_err)
						ESP_LOGI(TAG, "spi_device_polling_transmit RES:%i Error:%s", spi_err,
								esp_err_to_name(spi_err));

					//s_addr += 1364;
					if(i == 1)
						s_addr = (command & 0x00000001) ? 0x3000 : 0x2000;
					else
						s_addr += 1536;
					b_pos += 1536;
					t.addr = s_addr << 8;
					t.rx_buffer = &s_buf[b_pos];
					//spi_err = spi_device_transmit(handle, &t);
				}

				sendto(udp_sock, s_buf, 6 * 1024, 0, (struct sockaddr*)&sock_addr, sizeof(struct sockaddr_in));
			} else {
				spi_transaction_t t;
				uint32_t rx_dummy;
				memset(&t, 0, sizeof(t));
				t.cmd = (command >> 24) & 0xFF;
				t.addr = command & 0x00FFFFFF;
				t.flags = SPI_TRANS_MODE_QIO;
				t.length = 0;
				t.tx_buffer = NULL;
				t.rx_buffer = &rx_dummy; //NULL;
				t.rxlength = 32;
				esp_err_t ret = spi_device_polling_transmit(handle, &t);
				if (ESP_OK != ret)
					ESP_LOGI(TAG, "spi_device_polling_transmit RES:%i Error:%s",
							ret, esp_err_to_name(ret));
			}
		}
	}
}

void app_main(void)
{
	rbuf = malloc(1024);
	s_buf_one = malloc(8 * 1024);
	s_buf_two = malloc(8 * 1024);

	spi_queue = xQueueCreate(1000, sizeof(uint32_t));

	// Initialize TCP/IP network interface (should be called only once in application)
	ESP_ERROR_CHECK(esp_netif_init());

	// Create default event loop that running in background
	ESP_ERROR_CHECK(esp_event_loop_create_default());

	esp_netif_config_t cfg = ESP_NETIF_DEFAULT_ETH();
	esp_netif_t *eth_netif = esp_netif_new(&cfg);

	esp_netif_dhcpc_stop(eth_netif);
	char *ip = "10.0.0.11"; //"192.168.1.11";
	char *gateway = "10.0.0.1";
	char *netmask = "255.255.255.0";
	esp_netif_ip_info_t info_t;
	memset(&info_t, 0, sizeof(esp_netif_ip_info_t));
	ip4addr_aton((const char*) ip, (ip4_addr_t*) &info_t.ip.addr);
	ip4addr_aton((const char*) gateway, (ip4_addr_t*) &info_t.gw.addr);
	ip4addr_aton((const char*) netmask, (ip4_addr_t*) &info_t.netmask.addr);
	esp_netif_set_ip_info(eth_netif, &info_t);

	// Init MAC and PHY configs to default
	eth_phy_config_t phy_config = ETH_PHY_DEFAULT_CONFIG();
	phy_config.phy_addr = 0; //CONFIG_EXAMPLE_ETH_PHY_ADDR;
	phy_config.reset_gpio_num = -1; // No Hardware Reset //CONFIG_EXAMPLE_ETH_PHY_RST_GPIO;
	phy_config.autonego_timeout_ms = 1000;

	esp_eth_phy_t *phy = esp_eth_phy_new_lan87xx(&phy_config);

	eth_mac_config_t mac_config = ETH_MAC_DEFAULT_CONFIG();
	mac_config.smi_mdc_gpio_num = 23;
	mac_config.smi_mdio_gpio_num = 18;
	mac_config.clock_config.rmii.clock_mode = EMAC_CLK_OUT;
	mac_config.clock_config.rmii.clock_gpio = 17;

	esp_eth_mac_t *mac = esp_eth_mac_new_esp32(&mac_config);

	// phy->set_addr(phy, 1232122);
	esp_eth_config_t config = ETH_DEFAULT_CONFIG(mac, phy);
	esp_eth_handle_t eth_handle = NULL;
	ESP_ERROR_CHECK(esp_eth_driver_install(&config, &eth_handle));

	//attach Ethernet driver to TCP/IP stack
	ESP_ERROR_CHECK(esp_netif_attach(eth_netif, esp_eth_new_netif_glue(eth_handle)));

	ESP_ERROR_CHECK(esp_event_handler_register(ETH_EVENT, ESP_EVENT_ANY_ID, &eth_event_handler, NULL));
	ESP_ERROR_CHECK(esp_event_handler_register(IP_EVENT, IP_EVENT_ETH_GOT_IP, &got_ip_event_handler, NULL));

	// start Ethernet driver state machine
	ESP_ERROR_CHECK(esp_eth_start(eth_handle));

	udp_sock = socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP);
	ESP_LOGI(TAG, "Socket Handle: %i", udp_sock);

	uint8_t ttl = 128;
	ESP_ERROR_CHECK(setsockopt(udp_sock, IPPROTO_IP, IP_MULTICAST_TTL, &ttl, sizeof(uint8_t)));
	ESP_LOGI(TAG, "Socket TTL:128");

	struct sockaddr_in recv_addr;
	recv_addr.sin_addr.s_addr = htonl(INADDR_ANY);
	recv_addr.sin_family = AF_INET;
	recv_addr.sin_port = htons(10295);

	ESP_ERROR_CHECK(bind(udp_sock, (struct sockaddr*)&recv_addr, sizeof(recv_addr)));

	sock_addr.sin_family = AF_INET;
	sock_addr.sin_port = htons(10295);
	//sock_addr.sin_addr.s_addr = inet_addr("10.0.0.111");
	sock_addr.sin_addr.s_addr = inet_addr("224.10.11.12");

	ESP_ERROR_CHECK(setsockopt(udp_sock, IPPROTO_IP, IP_MULTICAST_IF, &sock_addr, sizeof(struct in_addr)));
	ESP_LOGI(TAG, "Socket IP_MULTICAST_IF");

	struct ip_mreq imreq = { 0 };
	imreq.imr_interface.s_addr = inet_addr("10.0.0.11");
	imreq.imr_multiaddr.s_addr = inet_addr("224.10.11.12");
	setsockopt(udp_sock, IPPROTO_IP, IP_ADD_MEMBERSHIP, &imreq, sizeof(struct ip_mreq));
	ESP_LOGI(TAG, "Socket IP_ADD_MEMBERSHIP");

	// ========================= SPI Initialize ==============================

	spi_bus_config_t buscfg = {
			.mosi_io_num = 2, //GPIO_MOSI,
			.miso_io_num = 4, //GPIO_MISO,
			.sclk_io_num = 5, //GPIO_SCLK,
			.quadwp_io_num = 32,
			.quadhd_io_num = 33,
			.max_transfer_sz = 0,
			.flags = SPICOMMON_BUSFLAG_MASTER | SPICOMMON_BUSFLAG_QUAD | SPICOMMON_BUSFLAG_GPIO_PINS
	};

	esp_err_t err = spi_bus_initialize(HSPI_HOST, &buscfg, SPI_DMA_CH1); // DISABLED);
	ESP_LOGI(TAG, "spi_bus_initialize Res:%i Error:%s", err, esp_err_to_name(err));

	spi_device_interface_config_t devcfg = {
			.command_bits = 8, //8,
			.address_bits = 24, //24,
			.dummy_bits = 0,
			.clock_speed_hz = 80 * 1000 * 1000,
			.duty_cycle_pos = 128,        //50% duty cycle
			.mode = 0,
			.spics_io_num = 16,
			.cs_ena_pretrans = 0, //Keep the CS low 3 cycles after transaction, to stop slave from missing the last bit when CS has less propagation delay than CLK
			.cs_ena_posttrans = 3,
			.queue_size = 8,
			.pre_cb = NULL,
			.post_cb = NULL,
			.flags = SPI_DEVICE_HALFDUPLEX
	};

	err = spi_bus_add_device(HSPI_HOST, &devcfg, &handle);
	ESP_LOGI(TAG, "spi_bus_add_device RES:%i Error:%s", err, esp_err_to_name(err));

	err = spi_device_acquire_bus(handle, portMAX_DELAY);
	ESP_LOGI(TAG, "spi_device_acquire_bus RES:%i Error:%s", err, esp_err_to_name(err));

	gpio_config_t sync_pin_conf = {
		.mode = GPIO_MODE_INPUT,
		.intr_type = GPIO_INTR_POSEDGE,
		.pin_bit_mask = 1ULL << sync_pin,
		.pull_up_en = 0
	};
	gpio_config(&sync_pin_conf);

	gpio_config_t half_pin_conf = {
		.mode = GPIO_MODE_INPUT,
		.intr_type = GPIO_INTR_DISABLE,
		.pin_bit_mask = 1ULL << half_pin,
		.pull_up_en = 0
	};
	gpio_config(&half_pin_conf);

	xTaskCreate(recv_task, "socket_recv", 2048, NULL, 10, &recv_task_handle);

	xTaskCreate(spi_task, "spi_task", 2048, NULL, 11, &spi_task_handle);

	err = gpio_install_isr_service(0);
	ESP_LOGI(TAG, "gpio_install_isr_service:%i Error:%s", err, esp_err_to_name(err));

	err = gpio_isr_handler_add(sync_pin, &gpio_isr_handler, NULL);
	ESP_LOGI(TAG, "gpio_isr_handler_add:%i Error:%s", err, esp_err_to_name(err));

	err = gpio_set_intr_type(sync_pin, GPIO_INTR_POSEDGE);
	ESP_LOGI(TAG, "gpio_set_intr_type:%i Error:%s", err, esp_err_to_name(err));

	err = gpio_intr_enable(sync_pin);
	ESP_LOGI(TAG, "gpio_intr_enable:%i Error:%s", err, esp_err_to_name(err));

	//uint32_t tmp = 0x12345678;
	while(1) {
		vTaskDelay(1000 / portTICK_PERIOD_MS);
		//xQueueSend(spi_queue, &tmp, 0);
		//tmp = ~tmp;
	}

//	int prev_sync_level = 0;
//	while(1) {
//		memset(s_buf, 0, 8 * 1024);
//
//		int sync_level = gpio_get_level(sync_pin);
//		if(prev_sync_level != sync_level) {
//			prev_sync_level = sync_level;
//			ESP_LOGI(TAG, "Sync Level Changed... IRQ_COUNTER=%i", irq_cntr);
//		}
//	}
}

