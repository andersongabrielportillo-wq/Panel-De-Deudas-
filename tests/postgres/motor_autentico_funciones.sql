-- Copia de definiciones originales extraidas SOLO LECTURA de staging.
-- SOLO ejecutar en PostgreSQL EFIMERO, NUNCA sobre staging/produccion.
CREATE OR REPLACE FUNCTION inv_private.verificar_reintento_venta(p_client_op_id uuid, p_hash text)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
    v_venta_id uuid;
    v_hash_guardado text;
BEGIN
    IF p_client_op_id IS NULL
       OR p_hash IS NULL
       OR length(p_hash) <> 64 THEN
        RAISE EXCEPTION
            'Identificador o huella inválidos';
    END IF;

    SELECT id, solicitud_hash
    INTO v_venta_id, v_hash_guardado
    FROM public.inv_ventas
    WHERE client_op_id = p_client_op_id;

    IF v_venta_id IS NULL THEN
        RETURN NULL;
    END IF;

    IF v_hash_guardado IS NULL
       OR v_hash_guardado <> p_hash THEN
        RAISE EXCEPTION
            'El identificador ya fue utilizado con datos diferentes';
    END IF;

    RETURN v_venta_id;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.inv_hash_solicitud_venta(p_vendedor_id uuid, p_modalidad text, p_articulos jsonb, p_descuento numeric, p_observaciones text)
 RETURNS text
 LANGUAGE sql
 IMMUTABLE
 SET search_path TO ''
AS $function$
    SELECT pg_catalog.encode(
        pg_catalog.sha256(
            pg_catalog.convert_to(
                pg_catalog.jsonb_build_array(
                    p_vendedor_id,
                    p_modalidad,
                    p_articulos,
                    p_descuento,
                    p_observaciones
                )::text,
                'UTF8'
            )
        ),
        'hex'
    );
$function$
;

CREATE OR REPLACE FUNCTION public.inv_registrar_movimiento(p_item_id uuid, p_tipo text, p_origen smallint, p_destino smallint, p_cantidad integer, p_vendedor text DEFAULT NULL::text, p_observaciones text DEFAULT NULL::text, p_client_op_id uuid DEFAULT NULL::uuid)
 RETURNS bigint
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
    v_usuario uuid;
    v_rol text;
    v_estado text;
    v_existencia integer;
    v_movimiento_id bigint;
    v_op_id uuid;
BEGIN
    IF p_origen = 4 OR p_destino = 4 THEN
      RAISE EXCEPTION 'Proveedor/Taller reservado para reparaciones';
    END IF;

    v_usuario := auth.uid();

    SELECT rol INTO v_rol
    FROM public.inv_members
    WHERE user_id = v_usuario;

    IF v_rol IS NULL OR v_rol NOT IN ('admin', 'secretaria') THEN
        RAISE EXCEPTION 'No tienes permiso para registrar movimientos';
    END IF;

    IF p_tipo IS NULL OR p_tipo NOT IN ('salida', 'traslado') THEN
        RAISE EXCEPTION 'Tipo de movimiento no permitido';
    END IF;

    IF p_cantidad IS NULL OR p_cantidad <= 0 THEN
        RAISE EXCEPTION 'La cantidad debe ser mayor que cero';
    END IF;

    IF p_origen IS NULL THEN
        RAISE EXCEPTION 'Debes indicar la ubicación de origen';
    END IF;

    IF p_tipo = 'salida' AND p_destino IS NOT NULL THEN
        RAISE EXCEPTION 'Una salida no debe tener destino interno';
    END IF;

    IF p_tipo = 'traslado'
       AND (p_destino IS NULL OR p_destino = p_origen) THEN
        RAISE EXCEPTION 'Selecciona un destino diferente al origen';
    END IF;

    SELECT estado INTO v_estado
    FROM public.inv_items
    WHERE id = p_item_id;

    IF v_estado IS DISTINCT FROM 'activo' THEN
        RAISE EXCEPTION 'El artículo no existe o no está activo';
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM public.inv_locations
        WHERE id = p_origen
    ) THEN
        RAISE EXCEPTION 'Ubicación de origen inválida';
    END IF;

    IF p_tipo = 'traslado' AND NOT EXISTS (
        SELECT 1 FROM public.inv_locations
        WHERE id = p_destino
    ) THEN
        RAISE EXCEPTION 'Ubicación de destino inválida';
    END IF;

    -- Serializar operaciones sobre el mismo artículo.
    PERFORM 1
    FROM public.inv_items
    WHERE id = p_item_id
    FOR UPDATE;

    -- Identificador para evitar operaciones duplicadas.
    v_op_id := COALESCE(p_client_op_id, gen_random_uuid());

    IF EXISTS (
        SELECT 1 FROM public.inv_movements
        WHERE client_op_id = v_op_id
    ) THEN
        RAISE EXCEPTION 'Esta operación ya fue registrada';
    END IF;

    SELECT cantidad INTO v_existencia
    FROM public.inv_stock
    WHERE item_id = p_item_id
      AND location_id = p_origen
    FOR UPDATE;

    IF COALESCE(v_existencia, 0) < p_cantidad THEN
        RAISE EXCEPTION
            'Existencias insuficientes. Disponibles: %, solicitadas: %',
            COALESCE(v_existencia, 0), p_cantidad;
    END IF;

    UPDATE public.inv_stock
    SET cantidad = cantidad - p_cantidad
    WHERE item_id = p_item_id
      AND location_id = p_origen;

    IF p_tipo = 'traslado' THEN
        INSERT INTO public.inv_stock (
            item_id, location_id, cantidad
        )
        VALUES (p_item_id, p_destino, p_cantidad)
        ON CONFLICT (item_id, location_id)
        DO UPDATE SET
            cantidad = public.inv_stock.cantidad + EXCLUDED.cantidad;
    END IF;

    INSERT INTO public.inv_movements (
        client_op_id,
        item_id,
        tipo,
        origen,
        destino,
        cantidad,
        fecha,
        vendedor,
        observaciones,
        usuario
    )
    VALUES (
        v_op_id,
        p_item_id,
        p_tipo,
        p_origen,
        p_destino,
        p_cantidad,
        CURRENT_DATE,
        p_vendedor,
        p_observaciones,
        v_usuario
    )
    RETURNING id INTO v_movimiento_id;

    RETURN v_movimiento_id;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.inv_registrar_venta(p_vendedor_id uuid, p_modalidad text, p_articulos jsonb, p_descuento numeric, p_observaciones text, p_client_op_id uuid)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
    v_usuario uuid;
    v_rol text;
    v_vendedor text;
    v_venta_id uuid;
    v_hash text;

    v_linea jsonb;
    v_item_id uuid;
    v_location smallint;
    v_cantidad integer;

    v_precio numeric;
    v_descuento_linea numeric;
    v_descuento_general numeric;

    v_subtotal numeric := 0;
    v_descuentos_lineas numeric := 0;
    v_total numeric;

    v_movimiento_id bigint;
    v_num_linea integer := 0;

    -- Límite del tipo numeric(14,2)
    v_maximo constant numeric := 999999999999.99;
BEGIN
    -- 1. AUTORIZACIÓN
    v_usuario := auth.uid();

    SELECT rol INTO v_rol
    FROM public.inv_members
    WHERE user_id = v_usuario;

    IF v_rol IS NULL
       OR v_rol NOT IN ('admin', 'secretaria') THEN
        RAISE EXCEPTION
            'No tienes permiso para registrar ventas';
    END IF;

    -- 2. IDENTIFICADOR OBLIGATORIO
    IF p_client_op_id IS NULL THEN
        RAISE EXCEPTION
            'La operación necesita un identificador único';
    END IF;

    -- 3. BLOQUEAR REINTENTOS CON EL MISMO ID
    -- El bloqueo dura hasta finalizar la transacción.
    PERFORM pg_catalog.pg_advisory_xact_lock(
        pg_catalog.hashtextextended(
            p_client_op_id::text, 0
        )
    );

    -- 4. CALCULAR HUELLA DE LA SOLICITUD
    v_hash := public.inv_hash_solicitud_venta(
        p_vendedor_id,
        p_modalidad,
        p_articulos,
        p_descuento,
        p_observaciones
    );

    -- 5. COMPROBAR REINTENTO
    v_venta_id :=
        inv_private.verificar_reintento_venta(
            p_client_op_id,
            v_hash
        );

    IF v_venta_id IS NOT NULL THEN
        RETURN v_venta_id;
    END IF;

    -- 6. VALIDAR VENDEDOR
    SELECT nombre INTO v_vendedor
    FROM public.inv_vendedores
    WHERE id = p_vendedor_id
      AND activo = true;

    IF v_vendedor IS NULL THEN
        RAISE EXCEPTION
            'El vendedor no existe o está inactivo';
    END IF;

    -- 7. VALIDAR MODALIDAD
    IF p_modalidad IS NULL
       OR p_modalidad NOT IN ('contado', 'credito') THEN
        RAISE EXCEPTION
            'Modalidad de venta inválida';
    END IF;

    -- 8. VALIDAR LISTA DE ARTÍCULOS
    IF p_articulos IS NULL
       OR pg_catalog.jsonb_typeof(p_articulos) <> 'array'
       OR pg_catalog.jsonb_array_length(p_articulos) = 0 THEN
        RAISE EXCEPTION
            'Debes incluir al menos un artículo';
    END IF;

    IF pg_catalog.jsonb_array_length(p_articulos) > 100 THEN
        RAISE EXCEPTION
            'Una venta no puede superar 100 líneas';
    END IF;

    -- 9. VALIDAR DESCUENTO GENERAL
    IF p_descuento IS NULL
       OR p_descuento < 0
       OR p_descuento > v_maximo
       OR p_descuento <> pg_catalog.round(p_descuento, 2) THEN
        RAISE EXCEPTION
            'Descuento general inválido';
    END IF;

    v_descuento_general := p_descuento;

    -- 10. VALIDAR Y CALCULAR CADA LÍNEA
    FOR v_linea IN
        SELECT value
        FROM pg_catalog.jsonb_array_elements(p_articulos)
    LOOP
        v_num_linea := v_num_linea + 1;

        IF pg_catalog.jsonb_typeof(v_linea) <> 'object' THEN
            RAISE EXCEPTION
                'Línea de venta inválida: %', v_num_linea;
        END IF;

        v_item_id := (v_linea->>'item_id')::uuid;
        v_location := (v_linea->>'location_id')::smallint;
        v_cantidad := (v_linea->>'cantidad')::integer;

        -- Usar numeric sin redondear inicialmente
        v_precio := (v_linea->>'precio_unitario')::numeric;

        v_descuento_linea :=
            COALESCE(
                (v_linea->>'descuento')::numeric,
                0
            );

        IF v_item_id IS NULL
           OR v_location IS NULL
           OR v_location NOT IN (1, 2)
           OR v_cantidad IS NULL
           OR v_cantidad <= 0
           OR v_precio IS NULL
           OR v_precio < 0
           OR v_precio > v_maximo
           OR v_precio <> pg_catalog.round(v_precio, 2)
           OR v_descuento_linea < 0
           OR v_descuento_linea > v_maximo
           OR v_descuento_linea <>
              pg_catalog.round(v_descuento_linea, 2)
        THEN
            RAISE EXCEPTION
                'Datos inválidos en línea %', v_num_linea;
        END IF;

        IF v_cantidad * v_precio > v_maximo THEN
            RAISE EXCEPTION
                'Importe demasiado grande en línea %',
                v_num_linea;
        END IF;

        IF v_descuento_linea >
           v_cantidad * v_precio THEN
            RAISE EXCEPTION
                'Descuento excesivo en línea %',
                v_num_linea;
        END IF;

        v_subtotal :=
            v_subtotal + v_cantidad * v_precio;

        v_descuentos_lineas :=
            v_descuentos_lineas + v_descuento_linea;

        IF v_subtotal > v_maximo
           OR v_descuentos_lineas > v_maximo THEN
            RAISE EXCEPTION
                'El importe de la venta supera el límite';
        END IF;
    END LOOP;

    -- 11. CALCULAR TOTAL
    IF v_descuento_general >
       v_subtotal - v_descuentos_lineas THEN
        RAISE EXCEPTION
            'El descuento supera el importe de la venta';
    END IF;

    v_total :=
        v_subtotal
        - v_descuentos_lineas
        - v_descuento_general;

    -- 12. CREAR ENCABEZADO
    INSERT INTO public.inv_ventas (
        vendedor_id,
        modalidad,
        subtotal,
        descuento,
        total,
        observaciones,
        registrado_por,
        client_op_id,
        solicitud_hash
    )
    VALUES (
        p_vendedor_id,
        p_modalidad,
        v_subtotal,
        v_descuentos_lineas + v_descuento_general,
        v_total,
        p_observaciones,
        v_usuario,
        p_client_op_id,
        v_hash
    )
    RETURNING id INTO v_venta_id;

    -- 13. REGISTRAR CADA ARTÍCULO
    FOR v_linea IN
        SELECT value
        FROM pg_catalog.jsonb_array_elements(p_articulos)
    LOOP
        v_item_id := (v_linea->>'item_id')::uuid;
        v_location := (v_linea->>'location_id')::smallint;
        v_cantidad := (v_linea->>'cantidad')::integer;
        v_precio := (v_linea->>'precio_unitario')::numeric;

        v_descuento_linea :=
            COALESCE(
                (v_linea->>'descuento')::numeric,
                0
            );

        -- Reutilizar la RPC original de inventario
        v_movimiento_id :=
            public.inv_registrar_movimiento(
                v_item_id,
                'salida',
                v_location,
                NULL::smallint,
                v_cantidad,
                v_vendedor,
                'Venta ' || v_venta_id::text,
                gen_random_uuid()
            );

        INSERT INTO public.inv_venta_detalles (
            venta_id,
            item_id,
            location_id,
            cantidad,
            precio_unitario,
            descuento,
            movimiento_id
        )
        VALUES (
            v_venta_id,
            v_item_id,
            v_location,
            v_cantidad,
            v_precio,
            v_descuento_linea,
            v_movimiento_id
        );
    END LOOP;

    RETURN v_venta_id;
END;
$function$
;
