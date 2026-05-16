package ome

import "core:container/queue"
import "core:fmt"
import "core:math"
import "core:math/rand"

Side :: enum {
	Buy,
	Sell,
}

Order :: struct {
	account_id: u64,
	side:       Side,
	amount:     i32,
	price:      f32,
}

PriceLevel :: struct {
	price:  f32,
	orders: queue.Queue(Order),
}

price_level_create :: proc(price: f32) -> PriceLevel {
	result := PriceLevel{price, {}}
	queue.init(&result.orders)

	return result
}

OrderBook :: struct {
	asks:       [dynamic]PriceLevel,
	bids:       [dynamic]PriceLevel,
	asks_count: u64,
	bids_count: u64,
}

orderbook_add_order :: proc(
	book: ^OrderBook,
	account_id: u64,
	side: Side,
	amount: i32,
	price: f32 = 0.0,
) {
	// market order
	if price == 0.0 {
		levels: ^[dynamic]PriceLevel
		count: ^u64 = nil
		if side == Side.Buy {
			levels = &book.asks
			count = &book.asks_count
		} else {
			levels = &book.bids
			count = &book.bids_count
		}

		delivered: i32 = 0
		for delivered != amount && len(levels) > 0 {
			level := &levels[0]
			order, ok := queue.pop_front_safe(&level.orders)
			if !ok {
				ordered_remove(levels, 0)
				continue
			}
			count^ -= 1

			new_delivery := math.min(amount - delivered, order.amount)
			delivered += new_delivery
			order.amount -= new_delivery

			if order.amount != 0 {
				queue.push_front(&level.orders, order)
				count^ += 1
			}
		}

		return
	}

	// limit order
	order := Order{account_id, side, amount, price}
	search_condition := proc(price: f32, side: Side, price_level: PriceLevel) -> bool {
		if side == Side.Buy {
			return price > price_level.price
		} else {
			return price < price_level.price
		}
	}
	levels: ^[dynamic]PriceLevel
	count: ^u64 = nil
	if side == Side.Buy {
		levels = &book.bids
		count = &book.bids_count
	} else {
		levels = &book.asks
		count = &book.asks_count
	}

	level: ^PriceLevel = nil
	if len(levels) == 0 {
		append(levels, price_level_create(price))
		level = &levels[0]
	} else {
		for i := 0; i < len(levels); i += 1 {
			if price == levels[i].price {
				level = &levels[i]
				break
			}
			if search_condition(price, side, levels[i]) {
				inject_at(levels, i, price_level_create(price))
				level = &levels[i]
				break
			}
		}
	}

	if level == nil {
		append(levels, price_level_create(price))
		level = &levels[len(levels) - 1]
	}

	queue.push_back(&level.orders, order)
	count^ += 1
}

orderbook_print_orders :: proc(book: OrderBook) {
	fmt.println("BIDS:")
	for i in 0 ..< len(book.bids) {
		price_level := book.bids[i]
		fmt.printf("PRICE: %.2f\n", price_level.price)
		for j in 0 ..< queue.len(price_level.orders) {
			order := queue.get_ptr(&price_level.orders, j)
			fmt.printf("	([%d] %d %.2f)\n", order.account_id, order.amount, order.price)
		}
		fmt.println()
	}

	fmt.println("ASKS:")
	for i in 0 ..< len(book.asks) {
		price_level := book.asks[i]
		fmt.printf("PRICE: %.2f\n", price_level.price)
		for j in 0 ..< queue.len(price_level.orders) {
			order := queue.get_ptr(&price_level.orders, j)
			fmt.printf("	([%d] %d %.2f)\n", order.account_id, order.amount, order.price)
		}
		fmt.println()
	}
	fmt.println("------")
}

orderbook_fill :: proc(
	orderbook: ^OrderBook,
	account_ids: ^[5]u64,
	count: int = 0,
	market: bool = false,
) {
	real_count := rand.int_max(15)
	if count > 0 {
		real_count = count
	}

	real_market: f32 = cast(f32)((int(market) + 1) % 2)
	for _ in 0 ..< real_count {
		orderbook_add_order(
			orderbook,
			account_ids[rand.int_max(5)],
			cast(Side)rand.int_max(2),
			1 + cast(i32)rand.int_max(999),
			real_market * cast(f32)(rand.int_max(999) / 10 * 100),
		)
	}
}
