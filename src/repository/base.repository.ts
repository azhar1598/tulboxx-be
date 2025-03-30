import { supabase } from "@/config/database";
import { PaginationOptions, PaginatedResponse } from "@/types/pagination";

export class BaseRepository<T> {
  constructor(
    protected readonly tableName: string,
    protected readonly primaryKey: string = "id"
  ) {}

  async findOne(id: number | string): Promise<T | null> {
    const { data, error } = await supabase
      .from(this.tableName)
      .select("*")
      .eq(this.primaryKey, id)
      .single();

    if (error) throw error;
    return data as T;
  }

  async findOneBy(conditions: Partial<T>): Promise<T | null> {
    let query = supabase.from(this.tableName).select("*");

    // Apply all conditions
    for (const [key, value] of Object.entries(conditions)) {
      query = query.eq(key, value);
    }

    const { data, error } = await query.single();

    if (error && error.code !== "PGRST116") throw error; // PGRST116 is "no rows returned"
    return data as T;
  }

  async findOneOrFail(id: number | string): Promise<T> {
    const result = await this.findOne(id);
    if (!result) {
      throw new Error(`Entity with ${this.primaryKey}=${id} not found`);
    }
    return result;
  }

  async find(options?: {
    where?: Partial<T>;
    orderBy?: string;
    order?: "asc" | "desc";
  }): Promise<T[]> {
    let query = supabase.from(this.tableName).select("*");

    if (options?.where) {
      // Apply all where conditions
      for (const [key, value] of Object.entries(options.where)) {
        query = query.eq(key, value);
      }
    }

    if (options?.orderBy) {
      query = query.order(options.orderBy, {
        ascending: options?.order !== "desc",
      });
    }

    const { data, error } = await query;

    if (error) throw error;
    return data as T[];
  }

  async findAndCount(
    options: PaginationOptions & {
      where?: Partial<T>;
      orderBy?: string;
      order?: "asc" | "desc";
    }
  ): Promise<PaginatedResponse<T>> {
    const { page, limit } = options;
    const offset = (page - 1) * limit;

    let query = supabase.from(this.tableName).select("*", { count: "exact" });

    if (options.where) {
      // Apply all where conditions
      for (const [key, value] of Object.entries(options.where)) {
        query = query.eq(key, value);
      }
    }

    if (options.orderBy) {
      query = query.order(options.orderBy, {
        ascending: options.order !== "desc",
      });
    }

    // Add pagination
    query = query.range(offset, offset + limit - 1);

    const { data, error, count } = await query;

    if (error) throw error;

    return {
      data: data as T[],
      total: count || 0,
      page,
      limit,
      totalPages: Math.ceil((count || 0) / limit),
    };
  }

  async create(entity: Partial<T>): Promise<T> {
    const { data, error } = await supabase
      .from(this.tableName)
      .insert(entity)
      .select()
      .single();

    if (error) throw error;
    return data as T;
  }

  async createMany(entities: Partial<T>[]): Promise<T[]> {
    const { data, error } = await supabase
      .from(this.tableName)
      .insert(entities)
      .select();

    if (error) throw error;
    return data as T[];
  }

  async update(id: number | string, entity: Partial<T>): Promise<T> {
    const { data, error } = await supabase
      .from(this.tableName)
      .update(entity)
      .eq(this.primaryKey, id)
      .select()
      .single();

    if (error) throw error;
    return data as T;
  }

  async delete(id: number | string): Promise<void> {
    const { error } = await supabase
      .from(this.tableName)
      .delete()
      .eq(this.primaryKey, id);

    if (error) throw error;
  }

  async count(conditions?: Partial<T>): Promise<number> {
    let query = supabase
      .from(this.tableName)
      .select("*", { count: "exact", head: true });

    if (conditions) {
      // Apply all conditions
      for (const [key, value] of Object.entries(conditions)) {
        query = query.eq(key, value);
      }
    }

    const { count, error } = await query;

    if (error) throw error;
    return count || 0;
  }

  async exist(conditions: Partial<T>): Promise<boolean> {
    const count = await this.count(conditions);
    return count > 0;
  }
}
