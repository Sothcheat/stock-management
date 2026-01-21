import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../design_system.dart';
import '../../auth/data/auth_repository.dart';
import '../../orders/data/orders_repository.dart';
import '../../orders/domain/order.dart';

class AddNewOrderScreen extends ConsumerStatefulWidget {
  const AddNewOrderScreen({super.key});

  @override
  ConsumerState<AddNewOrderScreen> createState() => _AddNewOrderScreenState();
}

class _AddNewOrderScreenState extends ConsumerState<AddNewOrderScreen> {
  final _formKey = GlobalKey<FormState>();

  // Customer Info
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _noteController = TextEditingController(); // Added note controller

  // Cart
  final List<OrderItem> _items = [];
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _noteController.dispose(); // Dispose note
    super.dispose();
  }

  double get _totalAmount =>
      _items.fold(0, (sum, item) => sum + (item.priceAtSale * item.quantity));

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
        id: '', // Repo will handle or Firestore auto-id
        customer: OrderCustomer(
          name: _nameController.text.trim(),
          primaryPhone: _phoneController.text.trim(),
          note: _noteController.text.trim(), // Include note
        ),
        deliveryAddress: _addressController.text.trim(),
        items: _items,
        totalAmount: _totalAmount,
        status: OrderStatus.prepping,
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
                            suffixIcon:
                                ValueListenableBuilder<TextEditingValue>(
                                  valueListenable: _nameController,
                                  builder: (context, value, child) {
                                    return value.text.isEmpty
                                        ? const SizedBox.shrink()
                                        : IconButton(
                                            icon: const Icon(
                                              Icons.clear,
                                              color: SoftColors.textSecondary,
                                            ),
                                            onPressed: _nameController.clear,
                                          );
                                  },
                                ),
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
                            suffixIcon:
                                ValueListenableBuilder<TextEditingValue>(
                                  valueListenable: _phoneController,
                                  builder: (context, value, child) {
                                    return value.text.isEmpty
                                        ? const SizedBox.shrink()
                                        : IconButton(
                                            icon: const Icon(
                                              Icons.clear,
                                              color: SoftColors.textSecondary,
                                            ),
                                            onPressed: _phoneController.clear,
                                          );
                                  },
                                ),
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
                            suffixIcon:
                                ValueListenableBuilder<TextEditingValue>(
                                  valueListenable: _addressController,
                                  builder: (context, value, child) {
                                    return value.text.isEmpty
                                        ? const SizedBox.shrink()
                                        : IconButton(
                                            icon: const Icon(
                                              Icons.clear,
                                              color: SoftColors.textSecondary,
                                            ),
                                            onPressed: _addressController.clear,
                                          );
                                  },
                                ),
                            maxLines: 2,
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
                            suffixIcon:
                                ValueListenableBuilder<TextEditingValue>(
                                  valueListenable: _noteController,
                                  builder: (context, value, child) {
                                    return value.text.isEmpty
                                        ? const SizedBox.shrink()
                                        : IconButton(
                                            icon: const Icon(
                                              Icons.clear,
                                              color: SoftColors.textSecondary,
                                            ),
                                            onPressed: _noteController.clear,
                                          );
                                  },
                                ),
                            maxLines: 2,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),

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
                            final result = await context.push<OrderItem>(
                              '/orders/product-selection',
                            );
                            if (result != null) {
                              setState(() {
                                _items.add(result);
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
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _items.length,
                        itemBuilder: (context, index) {
                          final item = _items[index];
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: SoftCard(
                              padding: const EdgeInsets.all(16),
                              child: Row(
                                children: [
                                  Container(
                                    width: 48,
                                    height: 48,
                                    decoration: BoxDecoration(
                                      color: SoftColors.brandPrimary.withValues(
                                        alpha: 0.1,
                                      ),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Center(
                                      child: Text(
                                        "${item.quantity}x",
                                        style: GoogleFonts.outfit(
                                          fontWeight: FontWeight.bold,
                                          color: SoftColors.brandPrimary,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          item.name,
                                          style: GoogleFonts.outfit(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                            color: SoftColors.textMain,
                                          ),
                                        ),
                                        Text(
                                          item.variantName,
                                          style: GoogleFonts.outfit(
                                            color: SoftColors.textSecondary,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        "\$${(item.priceAtSale * item.quantity).toStringAsFixed(2)}",
                                        style: GoogleFonts.outfit(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                          color: SoftColors.textMain,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      BounceButton(
                                        onTap: () {
                                          setState(() {
                                            _items.removeAt(index);
                                          });
                                        },
                                        child: Icon(
                                          Icons.delete_outline_rounded,
                                          size: 20,
                                          color: SoftColors.error.withValues(
                                            alpha: 0.7,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
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
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "Total Amount",
                        style: GoogleFonts.outfit(
                          fontSize: 16,
                          color: SoftColors.textSecondary,
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
                    label: "Create Order",
                    onTap: _submitOrder,
                    isLoading: _isLoading,
                    icon: Icons.check_circle_outline_rounded,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
