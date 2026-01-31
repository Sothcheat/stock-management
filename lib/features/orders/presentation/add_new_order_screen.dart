import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../design_system.dart';
import '../../inventory/data/inventory_repository.dart';
import '../../auth/data/auth_repository.dart';
import '../../orders/data/firebase_orders_repository.dart';
import '../../orders/domain/order.dart';

class AddNewOrderScreen extends ConsumerStatefulWidget {
  const AddNewOrderScreen({super.key});

  @override
  ConsumerState<AddNewOrderScreen> createState() => _AddNewOrderScreenState();
}

class _AddNewOrderScreenState extends ConsumerState<AddNewOrderScreen> {
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _noteController = TextEditingController();
  final _deliveryFeeController = TextEditingController();

  final List<OrderItem> _items = [];
  bool _isLoading = false;

  // Delivery
  double _deliveryFee = 0.0;
  String _deliveryType = 'Manual';

  @override
  void initState() {
    super.initState();
    // Listen to manual input changes
    _deliveryFeeController.addListener(() {
      final value = double.tryParse(_deliveryFeeController.text) ?? 0.0;
      if (_deliveryType == 'Manual' && value != _deliveryFee) {
        setState(() {
          _deliveryFee = value;
        });
      }
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _noteController.dispose();
    _deliveryFeeController.dispose();
    super.dispose();
  }

  double get _subtotal =>
      _items.fold(0, (sum, item) => sum + (item.priceAtSale * item.quantity));

  double get _totalAmount => _subtotal + _deliveryFee;

  void _setDeliveryOption(String type, double fee) {
    HapticFeedback.lightImpact();
    setState(() {
      _deliveryType = type;
      _deliveryFee = fee;
      if (type != 'Manual') {
        _deliveryFeeController.clear();
      } else {
        _deliveryFeeController.text = fee.toString();
      }
    });
  }

  Future<void> _submitOrder() async {
    if (!_formKey.currentState!.validate()) return;
    if (_items.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Add at least one product")));
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user = ref.read(authRepositoryProvider).currentUser;
      if (user == null) throw Exception("User not logged in");

      final order = OrderModel(
        id: '',
        customer: OrderCustomer(
          name: _nameController.text.trim(),
          primaryPhone: _phoneController.text.trim(),
        ),
        deliveryAddress: _addressController.text.trim(),
        items: _items,
        logistics: OrderLogistics(
          deliveryFeeCharged: _deliveryFee,
          deliveryType: _deliveryType,
          // actualDeliveryCost is NOT set here (Revenue side only)
        ),
        totalAmount: _totalAmount,
        status: OrderStatus.prepping,
        note: _noteController.text.trim(),
        createdBy: user.uid,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await ref.read(ordersRepositoryProvider).createOrder(order);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Order Created Successfully!"),
            backgroundColor: SoftColors.success,
          ),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (c) => AlertDialog(
            backgroundColor: SoftColors.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(SoftColors.cardRadius),
            ),
            title: Text(
              "Error",
              style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
            ),
            content: Text(
              e.toString(),
              style: GoogleFonts.outfit(color: SoftColors.textSecondary),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showEditQuantitySheet(OrderItem item) {
    showModalBottomSheet(
      context: context,
      backgroundColor: SoftColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return _EditQuantitySheet(
          item: item,
          onSave: (newQty) {
            setState(() {
              final index = _items.indexOf(item);
              if (index != -1) {
                // Check if qty 0? User might want to delete.
                if (newQty <= 0) {
                  _items.removeAt(index);
                } else {
                  _items[index] = item.copyWith(quantity: newQty);
                }
              }
            });
            Navigator.pop(context);
          },
        );
      },
    );
  }

  Widget _buildDeliveryOption(String label, String type, double fee) {
    // Strict Match: Type MUST match AND Fee MUST match
    final isSelected = _deliveryType == type && _deliveryFee == fee;

    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: InkWell(
        onTap: () => _setDeliveryOption(type, fee),
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: isSelected
                ? SoftColors.brandPrimary.withValues(alpha: 0.1)
                : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? SoftColors.brandPrimary : SoftColors.border,
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isSelected) ...[
                const Icon(
                  Icons.check_circle_rounded,
                  size: 16,
                  color: SoftColors.brandPrimary,
                ),
                const SizedBox(width: 8),
              ],
              Text(
                label,
                style: GoogleFonts.outfit(
                  color: isSelected
                      ? SoftColors.brandPrimary
                      : SoftColors.textSecondary,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SoftScaffold(
      title: "New Order",
      showBack: true,
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Customer Details",
                      style: GoogleFonts.outfit(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: SoftColors.textMain,
                      ),
                    ),
                    const SizedBox(height: 16),
                    SoftCard(
                      child: Column(
                        children: [
                          ModernInput(
                            controller: _nameController,
                            hintText: "Enter customer name",
                            labelText: "Customer Name",
                            prefixIcon: Icons.person_outline_rounded,
                            activePrefixIcon: Icons.person_rounded,
                            showClearButton: true,
                            validator: (v) =>
                                v?.isEmpty == true ? 'Required' : null,
                          ),
                          const SizedBox(height: 16),
                          ModernInput(
                            controller: _phoneController,
                            hintText: "Enter phone number",
                            labelText: "Phone Number",
                            prefixIcon: Icons.phone_outlined,
                            activePrefixIcon: Icons.phone_rounded,
                            showClearButton: true,
                            keyboardType: TextInputType.phone,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(15),
                            ],
                            validator: (v) =>
                                v?.isEmpty == true ? 'Required' : null,
                          ),
                          const SizedBox(height: 16),
                          ModernInput(
                            controller: _addressController,
                            hintText: "Enter delivery address",
                            labelText: "Delivery Address",
                            prefixIcon: Icons.location_on_outlined,
                            activePrefixIcon: Icons.location_on,
                            showClearButton: true,
                            keyboardType: TextInputType.text,
                            maxLines: 2,
                            textInputAction: TextInputAction.done,
                            validator: (v) =>
                                v?.isEmpty == true ? 'Required' : null,
                          ),
                          const SizedBox(height: 16),
                          ModernInput(
                            controller: _noteController,
                            hintText: "Optional note",
                            labelText: "Note (Optional)",
                            prefixIcon: Icons.note_outlined,
                            activePrefixIcon: Icons.note,
                            showClearButton: true,
                            keyboardType: TextInputType.text,
                            maxLines: 2,
                            textInputAction: TextInputAction.done,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Products Section
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "Products",
                          style: GoogleFonts.outfit(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: SoftColors.textMain,
                          ),
                        ),
                        BounceButton(
                          onTap: () async {
                            final result = await context.push<List<OrderItem>>(
                              '/orders/product-selection',
                              extra: _items,
                            );
                            if (result != null) {
                              setState(() {
                                _items.clear();
                                _items.addAll(result);
                              });
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: SoftColors.brandPrimary.withValues(
                                alpha: 0.1,
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.add_circle_outline_sharp,
                                  size: 18,
                                  color: SoftColors.brandPrimary,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  "Add Item",
                                  style: GoogleFonts.outfit(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: SoftColors.brandPrimary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    if (_items.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(32),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: SoftColors.textSecondary.withValues(
                              alpha: 0.2,
                            ),
                            width: 2,
                          ),
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: Column(
                          children: [
                            Icon(
                              Icons.shopping_cart_outlined,
                              size: 48,
                              color: SoftColors.textSecondary.withValues(
                                alpha: 0.3,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              "No items added yet",
                              style: GoogleFonts.outfit(
                                color: SoftColors.textSecondary,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _items.length,
                        separatorBuilder: (c, i) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final item = _items[index];
                          return Dismissible(
                            key: ValueKey(
                              "order_item_${item.productId}_${item.variantId}_$index",
                            ),
                            direction: DismissDirection.endToStart,
                            background: Container(
                              alignment: Alignment.centerRight,
                              padding: const EdgeInsets.only(right: 24),
                              decoration: BoxDecoration(
                                color: SoftColors.error.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(
                                  SoftColors.cardRadius,
                                ),
                              ),
                              child: const Icon(
                                Icons.delete_outline,
                                color: SoftColors.error,
                              ),
                            ),
                            onDismissed: (_) {
                              setState(() {
                                _items.removeAt(index);
                              });
                              HapticFeedback.mediumImpact();
                            },
                            child: BounceButton(
                              onTap: () => _showEditQuantitySheet(item),
                              child: SoftCard(
                                padding: const EdgeInsets.all(12),
                                child: _OrderItemRow(item: item),
                              ),
                            ),
                          );
                        },
                      ),

                    const SizedBox(height: 32),

                    // Delivery Fee Section
                    Text(
                      "Delivery Fee",
                      style: GoogleFonts.outfit(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: SoftColors.textMain,
                      ),
                    ),
                    const SizedBox(height: 16),
                    SoftCard(
                      child: Column(
                        children: [
                          Row(
                            children: [
                              _buildDeliveryOption("Free", "Free", 0.0),
                              _buildDeliveryOption("\$1.50", "Preset", 1.50),
                              _buildDeliveryOption("\$2.00", "Preset", 2.00),
                            ],
                          ),
                          const SizedBox(height: 16),
                          ModernInput(
                            controller: _deliveryFeeController,
                            labelText: "Manual Fee / Custom",
                            hintText: "Enter amount",
                            prefixIcon: Icons.delivery_dining_outlined,
                            showClearButton: true,
                            activePrefixIcon: Icons.delivery_dining,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(
                                RegExp(r'^\d*\.?\d*$'),
                              ),
                            ],
                            onChanged: (val) {
                              // If user types, switch to manual mode
                              setState(() {
                                _deliveryType = 'Manual';
                                _deliveryFee = double.tryParse(val) ?? 0.0;
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Bottom Area
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(32),
              ),
              boxShadow: [
                BoxShadow(
                  color: SoftColors.textMain.withValues(alpha: 0.05),
                  blurRadius: 20,
                  offset: const Offset(0, -5),
                ),
              ],
            ),
            child: SafeArea(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "Subtotal",
                          style: GoogleFonts.outfit(
                            fontSize: 14,
                            color: SoftColors.textSecondary,
                          ),
                        ),
                        Text(
                          "\$${_subtotal.toStringAsFixed(2)}",
                          style: GoogleFonts.outfit(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: SoftColors.textMain,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "Delivery Fee",
                          style: GoogleFonts.outfit(
                            fontSize: 14,
                            color: SoftColors.textSecondary,
                          ),
                        ),
                        Text(
                          "\$${_deliveryFee.toStringAsFixed(2)}",
                          style: GoogleFonts.outfit(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: SoftColors.brandPrimary,
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "Total Amount",
                          style: GoogleFonts.outfit(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: SoftColors.textMain,
                          ),
                        ),
                        Text(
                          "\$${_totalAmount.toStringAsFixed(2)}",
                          style: GoogleFonts.outfit(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: SoftColors.brandPrimary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    SoftButton(
                      label: "Create Reserved Order",
                      onTap: _submitOrder,
                      isLoading: _isLoading,
                      icon: Icons.check_circle_outline_rounded,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OrderItemRow extends ConsumerWidget {
  final OrderItem item;
  const _OrderItemRow({required this.item});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch precise product for image
    final productMap = ref.watch(productsMapByIdProvider).valueOrNull;
    final product = productMap?[item.productId];
    final imagePath = product?.imagePath;

    return Row(
      children: [
        // Thumbnail
        Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: SoftColors.brandPrimary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          clipBehavior: Clip.antiAlias,
          child: imagePath != null
              ? CachedNetworkImage(
                  imageUrl: imagePath,
                  fit: BoxFit.cover,
                  errorWidget: (context, url, error) => const Center(
                    child: Icon(
                      Icons.broken_image_outlined,
                      size: 20,
                      color: SoftColors.textSecondary,
                    ),
                  ),
                )
              : const Center(
                  child: Icon(
                    Icons.inventory_2_outlined,
                    size: 24,
                    color: SoftColors.brandPrimary,
                  ),
                ),
        ),
        const SizedBox(width: 12),
        // Details
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.name,
                style: GoogleFonts.outfit(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: SoftColors.textMain,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),

              Row(
                children: [
                  Text(
                    "\$${item.priceAtSale.toStringAsFixed(2)}",
                    style: GoogleFonts.outfit(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: SoftColors.textMain,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    "x${item.quantity}",
                    style: GoogleFonts.outfit(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: SoftColors.textSecondary,
                    ),
                  ),
                ],
              ),
              if (item.variantName != 'Standard')
                Text(
                  item.variantName,
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    color: SoftColors.textSecondary,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _EditQuantitySheet extends StatefulWidget {
  final OrderItem item;
  final ValueChanged<int> onSave;
  const _EditQuantitySheet({required this.item, required this.onSave});
  @override
  State<_EditQuantitySheet> createState() => _EditQuantitySheetState();
}

class _EditQuantitySheetState extends State<_EditQuantitySheet> {
  late int _qty;
  @override
  void initState() {
    super.initState();
    _qty = widget.item.quantity;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        24,
        24,
        24,
        MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            "Update Quantity",
            style: GoogleFonts.outfit(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            widget.item.name,
            style: GoogleFonts.outfit(
              color: SoftColors.textSecondary,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              BounceButton(
                onTap: _qty > 0
                    ? () {
                        HapticFeedback.lightImpact();
                        setState(() => _qty--);
                      }
                    : () {},
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.remove, color: SoftColors.textMain),
                ),
              ),
              SizedBox(
                width: 80,
                child: Text(
                  "$_qty",
                  textAlign: TextAlign.center,
                  style: GoogleFonts.outfit(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              BounceButton(
                onTap: () {
                  HapticFeedback.lightImpact();
                  setState(() => _qty++);
                },
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: SoftColors.brandPrimary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.add, color: SoftColors.brandPrimary),
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
          SoftButton(
            label: _qty == 0 ? "Remove Item" : "Update",
            isLoading: false,
            icon: _qty == 0 ? Icons.delete_outline : Icons.check,
            backgroundColor: _qty == 0
                ? SoftColors.error
                : SoftColors.brandPrimary,
            onTap: () {
              HapticFeedback.mediumImpact();
              widget.onSave(_qty);
            },
          ),
        ],
      ),
    );
  }
}
